#!/usr/bin/env python3
"""
Validates .bobmodes YAML files in the repository.
Checks for:
- Valid YAML syntax
- Required top-level structure (customModes key)
- Required fields in each mode definition

This script dynamically finds all .bobmodes files in the repository tree.
"""

import os
import sys
from pathlib import Path
import yaml


def find_bobmodes_files(root_dir="."):
    """Find all .bobmodes files in the repository."""
    bobmodes_files = []
    for root, dirs, files in os.walk(root_dir):
        # Skip .git and other hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for file in files:
            if file == ".bobmodes":
                bobmodes_files.append(os.path.join(root, file))
    return bobmodes_files


def validate_bobmodes_structure(data, filepath):
    """Validate the structure of a .bobmodes file."""
    errors = []
    
    # Check for customModes key
    if "customModes" not in data:
        errors.append(f"Missing required 'customModes' key")
        return errors
    
    if not isinstance(data["customModes"], list):
        errors.append(f"'customModes' must be a list")
        return errors
    
    # Validate each mode
    required_fields = ["slug", "name", "description", "roleDefinition", "whenToUse"]
    
    for idx, mode in enumerate(data["customModes"]):
        mode_id = mode.get("slug", f"mode_{idx}")
        
        # Check required fields
        for field in required_fields:
            if field not in mode:
                errors.append(f"Mode '{mode_id}': Missing required field '{field}'")
            elif not mode[field] or (isinstance(mode[field], str) and not mode[field].strip()):
                errors.append(f"Mode '{mode_id}': Field '{field}' is empty")
        
        # Validate slug format (lowercase with hyphens)
        if "slug" in mode:
            slug = mode["slug"]
            if not slug.replace("-", "").replace("_", "").isalnum():
                errors.append(f"Mode '{mode_id}': Slug should contain only lowercase letters, numbers, and hyphens")
    
    return errors


def validate_file(filepath):
    """Validate a single .bobmodes file."""
    print(f"\nValidating: {filepath}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
        
        if data is None:
            print(f"  ❌ ERROR: File is empty")
            return False
        
        # Validate structure
        errors = validate_bobmodes_structure(data, filepath)
        
        if errors:
            print(f"  ❌ FAILED: Found {len(errors)} error(s):")
            for error in errors:
                print(f"     - {error}")
            return False
        else:
            mode_count = len(data.get("customModes", []))
            print(f"  ✅ VALID: {mode_count} mode(s) defined")
            return True
            
    except yaml.YAMLError as e:
        print(f"  ❌ YAML SYNTAX ERROR:")
        print(f"     {str(e)}")
        return False
    except Exception as e:
        print(f"  ❌ ERROR: {str(e)}")
        return False


def main():
    """Main validation function."""
    print("=" * 60)
    print("Bob Modes YAML Validation")
    print("=" * 60)
    
    # Find all .bobmodes files
    bobmodes_files = find_bobmodes_files()
    
    if not bobmodes_files:
        print("\n⚠️  WARNING: No .bobmodes files found in repository")
        return 0
    
    print(f"\nFound {len(bobmodes_files)} .bobmodes file(s)")
    
    # Validate each file
    results = []
    for filepath in bobmodes_files:
        results.append(validate_file(filepath))
    
    # Summary
    print("\n" + "=" * 60)
    print("Validation Summary")
    print("=" * 60)
    
    passed = sum(results)
    failed = len(results) - passed
    
    print(f"Total files: {len(results)}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    
    if failed > 0:
        print("\n❌ Validation FAILED")
        return 1
    else:
        print("\n✅ All validations PASSED")
        return 0


if __name__ == "__main__":
    sys.exit(main())

# Made with Bob
