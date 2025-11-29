# Create a simple text file that we'll convert to show PDF parsing capability
content = """
# Sample Business Requirements Document

## Project Overview
This is a test document to verify PDF parsing functionality.

## Requirements
1. User authentication system
2. Dashboard with real-time analytics
3. API integration with third-party services

## Technical Stack
- Backend: Elixir/Phoenix
- Database: PostgreSQL
- Frontend: LiveView

## Expected Users
- 10,000 concurrent users
- 100,000 daily active users

## Compliance
- GDPR compliant
- SOC 2 Type II certified
"""

File.write!("/tmp/sample_brd.txt", content)
IO.puts("✅ Created sample text file at /tmp/sample_brd.txt")
IO.puts("\nNote: PDF creation requires external tools.")
IO.puts("For now, let's test the parser with this text file to ensure it works.")
