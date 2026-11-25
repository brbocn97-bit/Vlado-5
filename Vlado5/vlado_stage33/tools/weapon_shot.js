const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const OUT = '/home/user/vlado_stage33/build/captures';
const fs = require('fs');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: [
    '--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', m => { const t = m.text(); logs.push(t); if (/Stage33|ERROR|weapon/i.test(t)) console.log('[page]', t.slice(0,220)); });
  await page.goto('http://127.0.0.1:8124/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(70000);
  await page.screenshot({ path: OUT + '/w0_spawn.png', timeout: 180000 });
  console.log('shot spawn');
  // walk toward the pickups then press E
  for (const k of ['w','w','w']) { await page.keyboard.down(k); await page.waitForTimeout(900); await page.keyboard.up(k); }
  await page.waitForTimeout(4000);
  await page.screenshot({ path: OUT + '/w1_near_pickup.png', timeout: 180000 });
  console.log('shot near');
  await page.keyboard.press('f');
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/w2_mp40.png', timeout: 180000 });
  console.log('shot mp40');
  fs.writeFileSync(OUT + '/console.log', logs.join('\n'));
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
