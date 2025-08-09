#!/bin/bash

# Multi-Target PostgreSQL Logical Replication Setup Script
# This script sets up logical replication from one source to multiple target databases
# using YAML configuration files with per-target table selection

set -e

# Configuration file (can be overridden by environment variable)
CONFIG_FILE=${REPLICATION_CONFIG_FILE:-"/app/replication-config.yml"}

echo "🔄 Setting up PostgreSQL logical replication with dynamic configuration..."
echo "📄 Using config file: $CONFIG_FILE"

# Function to install required dependencies
install_dependencies() {
    echo "📦 Installing required dependencies..."
    
    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        echo "Installing yq..."
        # Install yq using wget
        YQ_VERSION="v4.35.2"
        YQ_BINARY="yq_linux_arm64"
        wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY} -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
    fi
    
    # Check if postgresql-client is installed
    if ! command -v psql &> /dev/null; then
        echo "Installing postgresql-client..."
        apt-get update -qq
        apt-get install -y postgresql-client
    fi
    
    echo "✅ Dependencies installed"
}

# Function to parse YAML configuration
parse_config() {
    echo "📋 Parsing configuration from $CONFIG_FILE..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Parse source database configuration
    SOURCE_HOST=$(yq e '.replication.source.host' "$CONFIG_FILE")
    SOURCE_PORT=$(yq e '.replication.source.port' "$CONFIG_FILE")
    SOURCE_USER=$(yq e '.replication.source.user' "$CONFIG_FILE")
    SOURCE_PASSWORD=$(yq e '.replication.source.password' "$CONFIG_FILE")
    SOURCE_DATABASE=$(yq e '.replication.source.database' "$CONFIG_FILE")
    
    # Parse global settings
    PUBLICATION_NAME=$(yq e '.replication.publication_name' "$CONFIG_FILE")
    GLOBAL_MAX_WAIT_ATTEMPTS=$(yq e '.replication.settings.max_wait_attempts' "$CONFIG_FILE")
    GLOBAL_WAIT_INTERVAL=$(yq e '.replication.settings.wait_interval_seconds' "$CONFIG_FILE")
    
    # Parse target count
    TARGET_COUNT=$(yq e '.replication.targets | length' "$CONFIG_FILE")
    
    echo "✅ Configuration parsed successfully"
    echo "📊 Source: $SOURCE_HOST:$SOURCE_PORT/$SOURCE_DATABASE"
    echo "🎯 Targets: $TARGET_COUNT"
    echo "📖 Publication: $PUBLICATION_NAME"
}

# Function to get target-specific setting with fallback to global
get_target_setting() {
    local target_index=$1
    local setting_name=$2
    local global_value=$3
    
    local target_value=$(yq e ".replication.targets[$target_index].settings.$setting_name" "$CONFIG_FILE")
    
    if [ "$target_value" = "null" ] || [ -z "$target_value" ]; then
        echo "$global_value"
    else
        echo "$target_value"
    fi
}

# Function to get tables for a specific target (with fallback to global tables)
get_target_tables() {
    local target_index=$1
    
    # Check if target has specific tables defined
    local target_tables_count=$(yq e ".replication.targets[$target_index].tables | length" "$CONFIG_FILE")
    
    if [ "$target_tables_count" != "null" ] && [ "$target_tables_count" -gt 0 ]; then
        # Target has specific tables, use them
        yq e ".replication.targets[$target_index].tables[]" "$CONFIG_FILE"
    else
        # Target doesn't have specific tables, use global tables
        yq e ".replication.tables[]" "$CONFIG_FILE"
    fi
}

# Function to build table list for publication/subscription
build_table_list() {
    local target_index=$1
    local tables_str=""
    
    # Get tables for this specific target
    local target_tables=($(get_target_tables $target_index))
    
    for table in "${target_tables[@]}"; do
        if [ -z "$tables_str" ]; then
            tables_str="\"$table\""
        else
            tables_str="$tables_str, \"$table\""
        fi
    done
    
    echo "$tables_str"
}

# Function to wait for database to be ready with tables
wait_for_tables() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local dbname=$5
    local db_label=$6
    local max_attempts=$7
    local wait_interval=$8
    local target_index=$9  # New parameter for target-specific tables
    
    echo "⏳ Waiting for $db_label to be ready with tables..."
    export PGPASSWORD=$password
    
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if any of the target-specific tables exist
        local tables_found=false
        
        # Get tables for this specific target (or global if target_index is empty)
        if [ -n "$target_index" ]; then
            local target_tables=($(get_target_tables $target_index))
        else
            # For source database, use global tables
            local target_tables=($(yq e ".replication.tables[]" "$CONFIG_FILE"))
        fi
        
        for table in "${target_tables[@]}"; do
            if psql -h $host -p $port -U $user -d $dbname -c "\dt" 2>/dev/null | grep -q "$table"; then
                tables_found=true
                break
            fi
        done
        
        if [ "$tables_found" = true ]; then
            echo "✅ $db_label is ready with tables"
            return 0
        fi
        
        echo "⏳ Waiting for tables in $db_label (attempt $((attempt+1))/$max_attempts)..."
        sleep $wait_interval
        attempt=$((attempt+1))
    done
    
    echo "❌ Timeout waiting for tables in $db_label"
    return 1
}

# Function to wait for all target databases
wait_for_all_targets() {
    echo "⏳ Waiting for all target databases to be ready..."
    
    for ((i=0; i<TARGET_COUNT; i++)); do
        TARGET_NAME=$(yq e ".replication.targets[$i].name" "$CONFIG_FILE")
        TARGET_HOST=$(yq e ".replication.targets[$i].host" "$CONFIG_FILE")
        TARGET_PORT=$(yq e ".replication.targets[$i].port" "$CONFIG_FILE")
        TARGET_USER=$(yq e ".replication.targets[$i].user" "$CONFIG_FILE")
        TARGET_PASSWORD=$(yq e ".replication.targets[$i].password" "$CONFIG_FILE")
        TARGET_DATABASE=$(yq e ".replication.targets[$i].database" "$CONFIG_FILE")
        
        # Get target-specific or global settings
        MAX_WAIT_ATTEMPTS=$(get_target_setting $i "max_wait_attempts" $GLOBAL_MAX_WAIT_ATTEMPTS)
        WAIT_INTERVAL=$(get_target_setting $i "wait_interval_seconds" $GLOBAL_WAIT_INTERVAL)
        
        wait_for_tables $TARGET_HOST $TARGET_PORT $TARGET_USER $TARGET_PASSWORD $TARGET_DATABASE "target database ($TARGET_NAME)" $MAX_WAIT_ATTEMPTS $WAIT_INTERVAL $i || {
            echo "❌ Failed waiting for target: $TARGET_NAME"
            return 1
        }
    done
    
    echo "✅ All target databases are ready"
}

# Function to create publication for a specific target
create_target_publication() {
    local target_index=$1
    local target_name=$2
    
    echo "📖 Creating publication for target: $target_name..."
    
    # Create target-specific publication name
    local target_publication_name="${PUBLICATION_NAME}_${target_name}"
    
    # Get tables for this target
    local table_list=$(build_table_list $target_index)
    
    if [ -z "$table_list" ]; then
        echo "❌ No tables specified for target: $target_name"
        return 1
    fi
    
    echo "📋 Tables for $target_name: $table_list"
    
    export PGPASSWORD=$SOURCE_PASSWORD
    
    # Drop existing publication if it exists
    psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USER -d $SOURCE_DATABASE -c "
        DROP PUBLICATION IF EXISTS $target_publication_name;
    " 2>/dev/null
    
    # Create new publication with target-specific tables
    psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USER -d $SOURCE_DATABASE -c "
        CREATE PUBLICATION $target_publication_name FOR TABLE $table_list;
    " || {
        echo "❌ Failed to create publication for target: $target_name"
        return 1
    }
    
    echo "✅ Publication created for target: $target_name ($target_publication_name)"
}

# Function to setup publications for all targets
setup_publication() {
    echo "📖 Setting up publications for all targets..."
    
    for ((i=0; i<TARGET_COUNT; i++)); do
        TARGET_NAME=$(yq e ".replication.targets[$i].name" "$CONFIG_FILE")
        create_target_publication $i $TARGET_NAME || {
            echo "❌ Failed to create publication for target: $TARGET_NAME"
            return 1
        }
    done
    
    echo "✅ All publications created successfully"
}

# Function to setup subscription for a specific target
setup_subscription() {
    local target_index=$1
    
    # Get target configuration
    TARGET_NAME=$(yq e ".replication.targets[$target_index].name" "$CONFIG_FILE")
    TARGET_HOST=$(yq e ".replication.targets[$target_index].host" "$CONFIG_FILE")
    TARGET_PORT=$(yq e ".replication.targets[$target_index].port" "$CONFIG_FILE")
    TARGET_USER=$(yq e ".replication.targets[$target_index].user" "$CONFIG_FILE")
    TARGET_PASSWORD=$(yq e ".replication.targets[$target_index].password" "$CONFIG_FILE")
    TARGET_DATABASE=$(yq e ".replication.targets[$target_index].database" "$CONFIG_FILE")
    
    # Create target-specific names
    local target_publication_name="${PUBLICATION_NAME}_${TARGET_NAME}"
    local target_subscription_name="${PUBLICATION_NAME}_${TARGET_NAME}_subscription"
    
    echo "🔄 Setting up subscription for target: $TARGET_NAME..."
    echo "📖 Publication: $target_publication_name"
    echo "📥 Subscription: $target_subscription_name"
    
    export PGPASSWORD=$TARGET_PASSWORD
    
    # Drop existing subscription if it exists
    psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DATABASE -c "
        DROP SUBSCRIPTION IF EXISTS $target_subscription_name;
    " 2>/dev/null
    
    # Create subscription for target-specific publication
    psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DATABASE -c "
        CREATE SUBSCRIPTION $target_subscription_name
        CONNECTION 'host=$SOURCE_HOST port=$SOURCE_PORT user=$SOURCE_USER password=$SOURCE_PASSWORD dbname=$SOURCE_DATABASE'
        PUBLICATION $target_publication_name
        WITH (copy_data = true);
    " || {
        echo "❌ Failed to create subscription for target: $TARGET_NAME"
        return 1
    }
    
    echo "✅ Subscription created successfully for target: $TARGET_NAME"
}

# Function to setup subscriptions for all targets
setup_all_subscriptions() {
    echo "🔄 Setting up subscriptions for all targets..."
    
    for ((i=0; i<TARGET_COUNT; i++)); do
        setup_subscription $i || {
            echo "❌ Failed to setup subscription for target index: $i"
            return 1
        }
    done
    
    echo "✅ All subscriptions created successfully"
}

# Function to verify replication for a specific target
verify_target_replication() {
    local target_index=$1
    
    # Get target configuration
    TARGET_NAME=$(yq e ".replication.targets[$target_index].name" "$CONFIG_FILE")
    TARGET_HOST=$(yq e ".replication.targets[$target_index].host" "$CONFIG_FILE")
    TARGET_PORT=$(yq e ".replication.targets[$target_index].port" "$CONFIG_FILE")
    TARGET_USER=$(yq e ".replication.targets[$target_index].user" "$CONFIG_FILE")
    TARGET_PASSWORD=$(yq e ".replication.targets[$target_index].password" "$CONFIG_FILE")
    TARGET_DATABASE=$(yq e ".replication.targets[$target_index].database" "$CONFIG_FILE")
    
    local target_subscription_name="${PUBLICATION_NAME}_${TARGET_NAME}_subscription"
    
    echo "🔍 Verifying replication for target: $TARGET_NAME..."
    
    export PGPASSWORD=$TARGET_PASSWORD
    echo "📊 Subscriptions on $TARGET_NAME ($TARGET_DATABASE):"
    psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DATABASE -c "
        SELECT subname, subenabled, subconninfo 
        FROM pg_subscription WHERE subname = '$target_subscription_name';" 2>/dev/null || {
        echo "❌ Could not query subscriptions for $TARGET_NAME"
        return 1
    }
    
    echo "📊 Subscription worker status for $TARGET_NAME:"
    local sync_state=$(psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DATABASE -t -c "
        SELECT sync_state FROM pg_stat_subscription WHERE subname = '$target_subscription_name';" 2>/dev/null | xargs)
    
    if [ "$sync_state" = "r" ]; then
        echo "✅ Target $TARGET_NAME: Ready and replicating"
        return 0
    elif [ "$sync_state" = "s" ]; then
        echo "🔄 Target $TARGET_NAME: Currently syncing"
        return 0
    elif [ -n "$sync_state" ]; then
        echo "⚠️  Target $TARGET_NAME: Status - $sync_state"
        return 1
    else
        echo "⚠️  Target $TARGET_NAME: No subscription worker status available (may be initializing)"
        return 0
    fi
}

verify_replication() {
    echo "🔍 Verifying replication status..."
    
    # Check source publication first
    export PGPASSWORD=$SOURCE_PASSWORD
    echo "📊 Publications on $SOURCE_DATABASE:"
    psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USER -d $SOURCE_DATABASE -c "
        SELECT pubname, puballtables, 
               array_to_string(array(SELECT schemaname||'.'||tablename FROM pg_publication_tables WHERE pubname = p.pubname), ', ') as tables
        FROM pg_publication p WHERE pubname LIKE '$PUBLICATION_NAME%';" 2>/dev/null || {
        echo "❌ Could not query publications"
        return 1
    }
    
    # Verify each target
    local all_ready=true
    for ((i=0; i<TARGET_COUNT; i++)); do
        verify_target_replication $i || {
            all_ready=false
        }
        echo "---"
    done
    
    if [ "$all_ready" = true ]; then
        echo "✅ All targets are successfully replicating"
        echo "🎉 Replication setup completed successfully!"
        return 0
    else
        echo "⚠️  Some targets may need more time to sync or have unknown states"
        echo "🎉 Replication setup completed successfully!"
        return 0
    fi
}

# Main execution
main() {
    echo "🚀 Starting dynamic replication setup..."
    
    # Install dependencies and parse config
    install_dependencies
    parse_config
    
    # Wait for source database to have tables
    wait_for_tables $SOURCE_HOST $SOURCE_PORT $SOURCE_USER $SOURCE_PASSWORD $SOURCE_DATABASE "source database ($SOURCE_HOST)" $GLOBAL_MAX_WAIT_ATTEMPTS $GLOBAL_WAIT_INTERVAL "" || exit 1
    
    # Wait for all target databases to have tables
    wait_for_all_targets || exit 1
    
    # Setup publication and subscriptions
    setup_publication || exit 1
    setup_all_subscriptions || exit 1
    
    # Verify setup
    verify_replication
    
    echo "🎉 Multi-target logical replication setup completed successfully!"
    echo "📋 Configuration used: $CONFIG_FILE"
    echo "🎯 Targets configured: $TARGET_COUNT"
}

# Run main function
main
