import { defineConfig } from '@playwright/test';

const port = Number(process.env.E2E_PORT ?? 4101);

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: {
    timeout: 10_000,
  },
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `MIX_ENV=test E2E_PORT=${port} mix run --no-halt e2e/support/fixture_server.exs`,
    cwd: '..',
    url: `http://127.0.0.1:${port}/api/v1/state`,
    timeout: 60_000,
    reuseExistingServer: !process.env.CI,
  },
});
