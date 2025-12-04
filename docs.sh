#!/usr/bin/env bash

# Generate versioned Roc documentation and organize into www/ directory
# Usage: ./docs.sh 0.1.0

set -euxo pipefail

VERSION=$1
PACKAGE_NAME=$(basename "$PWD")

# Validate version format (x.y.z)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format x.y.z (e.g., 0.1.0)"
    exit 1
fi

# Generate documentation with versioned root directory
roc docs --root-dir "/$PACKAGE_NAME/$VERSION/" package/main.roc

# Create versioned directory in www/
mkdir -p "www/$VERSION"

# Move generated docs to versioned directory
mv generated-docs/* "www/$VERSION/"

# Clean up
rmdir generated-docs

# Generate redirect index.html
cat > www/index.html <<EOF
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Redirecting...</title>
        <script>
            window.location.href = "/$PACKAGE_NAME/$VERSION/";
        </script>
    </head>
    <body>
        <noscript>
            <p>
                If you are not automatically redirected, please
                <a href="/$PACKAGE_NAME/$VERSION/">click here</a>.
            </p>
        </noscript>
    </body>
</html>
EOF

echo "Documentation generated successfully at www/$VERSION/"
echo "Root index.html updated to redirect to $VERSION"
