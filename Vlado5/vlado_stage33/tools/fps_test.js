const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const OUT = '/home/user/vlado_stage33/build/captures';
const fs = require('fs');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: [
    '--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t=m.text(); if (/Stage33|ERROR/i.test(t)) console.log('[page]', t.slice(0,200)); });
  await page.goto('http://127.0.0.1:8124/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(75000);
  // walk left toward the MP40 pedestal at (-8, 0, 2.5)
  await page.keyboard.down('a'); await page.waitForTimeout(1400); await page.keyboard.up('a');
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/f0_pedestal.png', timeout: 180000 });
  console.log('shot pedestal');
  await page.keyboard.press('f');
  await page.waitForTimeout(7000);
  await page.screenshot({ path: OUT + '/f1_tps_mp40.png', timeout: 180000 });
  console.log('shot TPS mp40');
  await page.keyboard.press('e');           // TPS -> FPS
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/f2_fps_mp40.png', timeout: 180000 });
  console.log('shot FPS mp40');
  await page.keyboard.press('q');           // swap to MG42
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/f3_fps_mg42.png', timeout: 180000 });
  console.log('shot FPS mg42');
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
