# Multi-Target PostgreSQL Logical Replication Setup

## Overview
This project now supports dynamic configuration of PostgreSQL logical replication from one source database to multiple target databases using YAML configuration files.

## Key Features

### 🎯 Multi-Target Support
- Configure replication from one source to multiple target databases
- Each target can have different connection parameters
- Target-specific settings with global fallbacks
- Independent subscription management per target

### 📋 Per-Target Table Selection
- **Global Tables**: Define default tables for all targets
- **Target-Specific Tables**: Override with custom table lists per target
- **Flexible Replication**: Different targets can replicate different subsets of data
- **Separate Publications**: Each target gets its own publication with specific tables

### 📋 YAML Configuration
- Dynamic configuration via YAML files
- Flexible table selection per target or globally
- Per-target custom settings
- Global default settings

### 🔄 Enhanced Setup Script
The `setup-replication.sh` script now supports:
- Multiple target database configuration
- Per-target table selection with fallbacks
- Target-specific publication creation
- Per-target wait times and retry attempts
- Individual subscription setup and verification
- Comprehensive status reporting

## Configuration Files

### 1. Single Target (Original)
- `replication-config.yml` - Single source to single target

### 3. Multi-Target Production
- `multi-target-config.yml` - Multiple production targets with different settings

## Usage

### Running with Different Configurations

1. **Single Target (Default)**:
   ```bash
   # Uses replication-config.yml
   export REPLICATION_CONFIG_FILE=/app/replication-config.yml
   docker-compose up
   ```

2. **Multi-Target Test**:
   ```bash
   # Uses test-multi-target-config.yml (current default)
   export REPLICATION_CONFIG_FILE=/app/test-multi-target-config.yml
   docker-compose up
   ```

3. **Multi-Target Production**:
   ```bash
   # Uses multi-target-config.yml
   export REPLICATION_CONFIG_FILE=/app/multi-target-config.yml
   docker-compose up
   ```

### Configuration Structure

```yaml
replication:
  source:
    host: source_host
    port: 5432
    user: postgres
    password: password
    database: source_db
  
  targets:
    - name: "target1"
      host: target1_host
      port: 5432
      user: postgres
      password: password
      database: target1_db
      # Target-specific tables (optional)
      tables:
        - users
        - orders
        - products
      settings:
        max_wait_attempts: 60
        wait_interval_seconds: 5
    
    - name: "target2"
      host: target2_host
      port: 5432
      user: postgres
      password: password
      database: target2_db
      # Different tables for this target
      tables:
        - users
        - orders
        # Note: products excluded from target2
      # Uses global settings
  
  # Global default tables (used if target doesn't specify tables)
  tables:
    - users
    - orders
    - products
    - transactions
  
  settings:
    publication_name: my_publication
    max_wait_attempts: 30
    wait_interval_seconds: 3
```

## Per-Target Table Configuration

### How It Works
1. **Target-Specific Tables**: If a target defines a `tables` array, it will only replicate those tables
2. **Global Fallback**: If a target doesn't define tables, it uses the global `tables` array
3. **Separate Publications**: Each target gets its own publication (e.g., `my_publication_target1`)
4. **Independent Subscriptions**: Each target subscribes to its specific publication

### Benefits
- **Data Isolation**: Analytics targets can exclude sensitive data
- **Performance**: Backup targets can include only critical tables
- **Compliance**: Different regions can have different data requirements
- **Flexibility**: Easy to add/remove tables per target without affecting others

## New Functions

### Core Functions
- `parse_config()` - Parses YAML and sets up variables for multiple targets
- `get_target_setting()` - Gets target-specific settings with global fallbacks
- `get_target_tables()` - Gets target-specific tables with global fallback
- `build_table_list()` - Builds formatted table list for SQL commands
- `wait_for_all_targets()` - Waits for all target databases to be ready
- `setup_publication()` - Creates separate publications for each target
- `setup_all_subscriptions()` - Creates subscriptions for all targets
- `verify_replication()` - Verifies replication status for all targets

### Per-Target Functions
- `create_target_publication(target_index, target_name)` - Creates publication for specific target
- `setup_subscription(target_index)` - Sets up subscription for specific target
- `verify_target_replication(target_index)` - Verifies specific target status

## Benefits

1. **Scalability**: Easy to add new target databases
2. **Flexibility**: Different settings and tables per target
3. **Data Governance**: Control what data goes to which targets
4. **Performance Optimization**: Reduce network and storage overhead
5. **Maintainability**: Single configuration file approach
6. **Monitoring**: Individual target status reporting
7. **Reliability**: Per-target error handling and retry logic
8. **Compliance**: Meet different data requirements per region/purpose

## Testing

The setup is currently configured to test with two subscriptions to the same target database to demonstrate multi-target functionality without requiring additional database containers.

To test with actual multiple databases, update the docker-compose.yml to include additional PostgreSQL services (postgres3, postgres4, etc.) and use the `multi-target-config.yml` configuration.
