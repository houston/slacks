### v0.6.4
- Removed reliance on faraday-raise-errors in favor of using built-in Faraday::RaiseError middleware

### v0.6.3
- Removed remaining calls to `.present?`, since we're not actually dependent on ActiveSupport

### v0.6.2
- Fixed a regression where groups, DMs, and private channels were not fetched

### v0.6.1
- Fixed a typo with creating a DM associated with a user

### v0.6.0
- Switched to using the Slack Conversations API
