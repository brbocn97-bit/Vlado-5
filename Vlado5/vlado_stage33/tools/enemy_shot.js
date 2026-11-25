const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const OUT = '/home/user/vlado_stage33/build/captures';
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t=m.text(); if (/Stage4|Stage33|ERROR/i.test(t)) console.log('[page]', t.slice(0,180)); });
  await page.goto('http://127.0.0.1:8124/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(75000);
  // F7 = Axis_Checkpoint (has 4 soldiers)
  await page.keyboard.press('F7');
  await page.waitForTimeout(18000);
  await page.screenshot({ path: OUT + '/e0_checkpoint.png', timeout: 180000 });
  console.log('shot checkpoint');
  // F6 = Crnca_Village (2 soldiers on the street)
  await page.keyboard.press('F6');
  await page.waitForTimeout(18000);
  await page.screenshot({ path: OUT + '/e1_crnca.png', timeout: 180000 });
  console.log('shot crnca');
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
