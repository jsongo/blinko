#!/bin/bash
lsof -ti :1111 | xargs kill -9 2>/dev/null || true