#!/bin/bash
# Test script to simulate curl | bash execution context

# Simulate how bash -c "$(curl ...)" works
echo "Testing donetick.sh in curl-like execution context..."
echo

# Test 1: Direct execution (should work)
echo "=== Test 1: Direct execution ==="
bash donetick.sh --help
echo

# Test 2: Simulate bash -c execution (the problematic case)
echo "=== Test 2: Simulated bash -c execution ==="
script_content=$(cat donetick.sh)
bash -c "$script_content --help"
echo

echo "All tests completed!"
