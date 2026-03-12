#### Context
This addresses a security vulnerability related to hardcoded signing salts in the application configuration and Phoenix endpoint.

#### TL;DR
Replaces static compile-time signing salts for LiveView and Session endpoints with dynamic runtime variables and configuration fetching.

#### Summary
🎯 **What:** The `signing_salt` for the session endpoint and live view sockets were either statically hardcoded as strings or evaluated at compile time due to being defined inside module attributes (`@session_options`).

⚠️ **Risk:** Statically baking the signing salt at compile time into the beam artifacts means every deployed instance running the release will share the exact same generated salt, and it could be easily predictable if the repository was leaked, creating a vulnerability against session manipulation.

🛡️ **Solution:**
1. Moved the `signing_salt` configuration out of the `@session_options` compile-time attribute into a dedicated runtime function `session_options/0` which correctly calls `System.get_env/1`.
2. Changed the `Plug.Session` initialization in `endpoint.ex` from using the static module attribute to a dynamic plug that invokes `session_options/0` at runtime.
3. Updated the LiveView socket configuration to fetch the session options via an MFA tuple (`{__MODULE__, :session_options, []}`) ensuring dynamic evaluation per connection.
4. Removed the hardcoded string `"symphony-live-view"` from `config.exs` and replaced it with an environment variable lookup with a randomly generated fallback.

#### Alternatives
N/A

#### Test Plan
- Run `make test` / `mix test` to ensure existing dashboard and live view specs pass using the dynamic configurations.
- Verify through `mix sobelow` that the framework is secure against predictable salts.
