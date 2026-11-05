# TaskZero privacy note

TaskZero operates locally. During an inspection it reads process metadata available to the current user, including:

- PID and parent PID
- process name and executable path
- user ID and display name
- application bundle identifier when available
- code-signing classification
- process start time
- resident memory and accumulated CPU time when available

The metadata is used to create the current preview and is not uploaded or sent to a server. Cleanup history stores the local summary and item metadata needed to explain what happened. The history is capped at 20 records and can be cleared from the History screen. User-configured exclusions and settings are stored in `UserDefaults`.

TaskZero does not collect analytics, create an account, inspect file contents, or request administrator privileges for ordinary cleanup.
