#!/bin/bash

# 获取最新的 tag
LATEST_TAG=$(git tag --sort=-v:refname | head -1)

if [ -z "$LATEST_TAG" ]; then
    echo "No tags found. Creating first tag v1.0.0"
    NEW_TAG="v1.0.0"
else
    echo "Latest tag: $LATEST_TAG"

    # 移除 v 前缀并分解版本号
    VERSION=${LATEST_TAG#v}
    IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"

    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    PATCH=${VERSION_PARTS[2]}

    # 根据参数决定增加哪一段
    case "$1" in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            echo "Incrementing major version"
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            echo "Incrementing minor version"
            ;;
        patch|*)
            PATCH=$((PATCH + 1))
            echo "Incrementing patch version"
            ;;
    esac

    NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}"
fi

echo "New tag: $NEW_TAG"
echo ""

# 确认是否继续
read -p "Create and push tag $NEW_TAG? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 创建 tag
    git tag "$NEW_TAG"
    if [ $? -eq 0 ]; then
        echo "✓ Tag $NEW_TAG created successfully"

        # 推送 tag
        git push origin "$NEW_TAG"
        if [ $? -eq 0 ]; then
            echo "✓ Tag $NEW_TAG pushed to origin"
        else
            echo "✗ Failed to push tag"
            exit 1
        fi
    else
        echo "✗ Failed to create tag"
        exit 1
    fi
else
    echo "Cancelled"
    exit 0
fi
