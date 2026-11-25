// Teleports through all six regions with F5..F10 and screenshots each one.
const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const fs = require('fs');
const BASE = process.argv[2] || 'http://127.0.0.1:8124';
const OUT = '/home/user/vlado_stage33/build/captures';
const REGIONS = ['krupa_valley','crnca_village','axis_checkpoint','durmitor_hideout','canyon_crossings','lovcen_peaks'];
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: [
    '--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader',
    '--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t=m.text(); if(t.includes('Stage4')||t.includes('ERROR')) console.log('[page]', t.slice(0,240)); });
  await page.goto(BASE + '/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(70000);
  await page.screenshot({ path: OUT + '/tour_00_spawn.png', timeout: 180000 });
  console.log('shot spawn');
  const keys = ['F5','F6','F7','F8','F9','F10'];
  for (let i = 0; i < keys.length; i++) {
    await page.keyboard.press(keys[i]);
    await page.waitForTimeout(20000);
    const f = `${OUT}/tour_${String(i+1).padStart(2,'0')}_${REGIONS[i]}.png`;
    await page.screenshot({ path: f, timeout: 180000 });
    console.log('shot', REGIONS[i]);
  }
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
