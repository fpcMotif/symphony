import { expect, test } from '@playwright/test';

test('dashboard renders, supports interactions, and refreshes live state', async ({ context, page, request }) => {
  await context.grantPermissions(['clipboard-write']);
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        writeText: async () => undefined,
      },
    });
  });
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'Operations Dashboard' })).toBeVisible();
  await expect(page.getByText('Running', { exact: true })).toBeVisible();
  await expect(page.getByText('Retrying', { exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Running sessions' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Retry queue' })).toBeVisible();
  await expect(page.getByText('MT-RUN')).toBeVisible();
  await expect(page.getByText('MT-RETRY')).toBeVisible();

  const copyButton = page.locator('button[data-copy="thread-dashboard-1"]');
  await expect(copyButton).toBeVisible();
  await expect(copyButton).toHaveAttribute('data-label', 'Copy ID');
  await copyButton.click();

  const detailsLink = page.getByRole('link', { name: 'JSON details' }).first();
  const href = await detailsLink.getAttribute('href');
  expect(href).toBe('/api/v1/MT-RUN');

  const issueResponse = await request.get(href!);
  expect(issueResponse.ok()).toBeTruthy();
  const issuePayload = await issueResponse.json();
  expect(issuePayload.issue_identifier).toBe('MT-RUN');
  expect(issuePayload.running.session_id).toBe('thread-dashboard-1');

  const statePayload = await page.evaluate(async () => {
    const response = await fetch('/api/v1/state');
    return { status: response.status, body: await response.json() };
  });

  expect(statePayload.status).toBe(200);
  expect(statePayload.body.counts.running).toBe(1);
  expect(statePayload.body.counts.retrying).toBe(1);

  const navigations: string[] = [];
  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) {
      navigations.push(frame.url());
    }
  });

  const refreshPayload = await page.evaluate(async () => {
    const response = await fetch('/api/v1/refresh', { method: 'POST' });
    return { status: response.status, body: await response.json() };
  });

  expect(refreshPayload.status).toBe(202);
  expect(refreshPayload.body.queued).toBe(true);
  expect(refreshPayload.body.operations).toEqual(['poll', 'reconcile']);

  await expect(page.getByText('agent message content streaming: refreshed update 1')).toBeVisible();
  await expect(page.getByText('Total: 22')).toBeVisible();
  expect(navigations).toHaveLength(0);
});
