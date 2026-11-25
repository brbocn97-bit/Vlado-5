const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const OUT = '/home/user/vlado_stage33/build/captures';
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t=m.text(); if (/Preuzeto|Podigni|Stage33\]/i.test(t)) console.log('[page]', t.slice(0,150)); });
  await page.goto('http://127.0.0.1:8124/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(80000);
  // walk left ~3 m to reach the MP40 pedestal at x=-8 (spawn x=-5)
  await page.keyboard.down('w'); await page.waitForTimeout(4200); await page.keyboard.up('w');
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/p0_prompt.png', timeout: 180000 });
  await page.keyboard.press('f');
  await page.waitForTimeout(8000);
  await page.screenshot({ path: OUT + '/p1_taken.png', timeout: 180000 });
  await page.keyboard.press('e');
  await page.waitForTimeout(10000);
  await page.screenshot({ path: OUT + '/p2_fps.png', timeout: 180000 });
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
