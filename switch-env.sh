#!/bin/bash

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {staging|prod|local|dc|beta}"
    exit 1
fi

ENVIRONMENT=$1

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "local" && "$ENVIRONMENT" != "dc" && "$ENVIRONMENT" != "beta" ]]; then
    echo "Error: Argument must be 'staging' or 'prod' or 'local' or 'dc' or 'beta'."
    exit 1
fi

# Function to find the root directory by looking for WireGuard.xcodeproj folder
find_root() {
    DIR=$(pwd)
    while [ "$DIR" != "/" ]; do
        if [ -d "$DIR/WireGuard.xcodeproj" ]; then
            echo "$DIR"
            return
        fi
        DIR=$(dirname "$DIR")
    done
    echo "Error: Could not find WireGuard.xcodeproj folder in any parent directories."
    exit 1
}

ROOT_DIR=$(find_root)

echo "Project root found at: $ROOT_DIR"

# Copy files depending on the environment
case "$ENVIRONMENT" in
    staging)
        echo "Changing configs to the staging environment..."
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Staging/Staging.Config.Example" "$ROOT_DIR/Sources/WireGuardApp/ClientConfig/Config.swift"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Staging/Staging.FastLane.example" "$ROOT_DIR/fastlane/Appfile"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Staging/Staging.Info.Plist.example" "$ROOT_DIR/Sources/WireGuardApp/UI/iOS/Info.plist"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Staging/Staging.xcconfig.example" "$ROOT_DIR/Sources/WireGuardApp/Config/Config.xcconfig"    
        ;;
    prod)
        echo "Changing configs to the production environment..."
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Prod/Prod.Config.Example" "$ROOT_DIR/Sources/WireGuardApp/ClientConfig/Config.swift"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Prod/Prod.FastLane.example" "$ROOT_DIR/fastlane/Appfile"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Prod/Prod.Info.Plist.example" "$ROOT_DIR/Sources/WireGuardApp/UI/iOS/Info.plist"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Prod/Prod.xcconfig.example" "$ROOT_DIR/Sources/WireGuardApp/Config/Config.xcconfig"    
        ;;
    local)
        echo "Changing configs to the local environment..."
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Local/Local.Config.Example" "$ROOT_DIR/Sources/WireGuardApp/ClientConfig/Config.swift"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Local/Local.FastLane.example" "$ROOT_DIR/fastlane/Appfile"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Local/Local.Info.Plist.example" "$ROOT_DIR/Sources/WireGuardApp/UI/iOS/Info.plist"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Local/Local.xcconfig.example" "$ROOT_DIR/Sources/WireGuardApp/Config/Config.xcconfig"           
        ;;
    dc)
        echo "Changing configs to the DC environment..."
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Dc/Dc.Config.Example" "$ROOT_DIR/Sources/WireGuardApp/ClientConfig/Config.swift"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Dc/Dc.FastLane.example" "$ROOT_DIR/fastlane/Appfile"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Dc/Dc.Info.Plist.example" "$ROOT_DIR/Sources/WireGuardApp/UI/iOS/Info.plist" 
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Dc/Dc.xcconfig.example" "$ROOT_DIR/Sources/WireGuardApp/Config/Config.xcconfig"    
        ;;

    beta)
        echo "Changing configs to the Beta environment..."
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Beta/Beta.Config.Example" "$ROOT_DIR/Sources/WireGuardApp/ClientConfig/Config.swift"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Beta/Beta.FastLane.example" "$ROOT_DIR/fastlane/Appfile"
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Beta/Beta.Info.Plist.example" "$ROOT_DIR/Sources/WireGuardApp/UI/iOS/Info.plist" 
        cp "$ROOT_DIR/Sources/WireGuardApp/Envs/Beta/Beta.xcconfig.example" "$ROOT_DIR/Sources/WireGuardApp/Config/Config.xcconfig"        
        ;;        
esac

echo "Done"
