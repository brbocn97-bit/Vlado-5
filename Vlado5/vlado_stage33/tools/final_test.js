const { chromium } = require('/home/user/.tools/node_modules/playwright-core');
const OUT = '/home/user/vlado_stage33/build/captures';
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', m => { const t=m.text(); logs.push(t); if (/Stage4|Stage33|Missions|Quality|ERROR/i.test(t)) console.log('[page]', t.slice(0,150)); });
  await page.goto('http://127.0.0.1:8124/index.html', { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForTimeout(80000);
  await page.screenshot({ path: OUT + '/t0_spawn.png', timeout: 180000 });
  console.log('shot spawn');
  // pick up the MP40 (walk left then press F)
  await page.keyboard.down('a'); await page.waitForTimeout(1500); await page.keyboard.up('a');
  await page.waitForTimeout(3500);
  await page.keyboard.press('f');
  await page.waitForTimeout(7000);
  await page.screenshot({ path: OUT + '/t1_tps_mp40.png', timeout: 180000 });
  console.log('shot TPS mp40');
  await page.keyboard.press('e');
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/t2_fps_mp40.png', timeout: 180000 });
  console.log('shot FPS mp40');
  await page.keyboard.press('q');
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/t3_fps_mg42.png', timeout: 180000 });
  console.log('shot FPS mg42');
  await page.keyboard.press('e');
  await page.waitForTimeout(6000);
  await page.keyboard.press('F7');   // Axis checkpoint with soldiers
  await page.waitForTimeout(20000);
  await page.screenshot({ path: OUT + '/t4_checkpoint.png', timeout: 180000 });
  console.log('shot checkpoint');
  await page.keyboard.press('F9');   // canyon waterfalls
  await page.waitForTimeout(20000);
  await page.screenshot({ path: OUT + '/t5_canyon.png', timeout: 180000 });
  console.log('shot canyon');
  fs.writeFileSync(OUT + '/final_console.log', logs.join('\n'));
  await browser.close();
})().catch(e => { console.error('FATAL', e.message.slice(0,300)); process.exit(1); });
