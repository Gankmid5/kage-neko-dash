const LEVELS = window.KageLevels;
const sfx = window.KageSfx;

const GRAVITY = 2970;
const JUMP_VEL = -812;
const DOUBLE_JUMP_VEL = -730;
const FAST_FALL_ACCEL = 4800;
const SLASH_DURATION = 0.16;
const SLASH_COOLDOWN = 0.16;
const SAVE_KEY = 'kage_neko_dash_web_save';

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const stageLabel = document.getElementById('stage-label');
const attemptLabel = document.getElementById('attempt-label');
const progressBar = document.getElementById('progress-bar');
const progressLabel = document.getElementById('progress-label');
const slashLabel = document.getElementById('slash-label');
const menuBtn = document.getElementById('menu-btn');
const muteBtn = document.getElementById('mute-btn');

const menuOverlay = document.getElementById('menu-overlay');
const playBtn = document.getElementById('play-btn');
const clearOverlay = document.getElementById('clear-overlay');
const clearTitle = document.getElementById('clear-title');
const clearStats = document.getElementById('clear-stats');
const replayBtn = document.getElementById('replay-btn');
const nextBtn = document.getElementById('next-btn');

let currentIdx = 0;
let attempt = 1;
let slashedCount = 0;
let comboCount = 0;
let comboTimer = 0;
let respawnTimer = -1;
let hitstopTimer = 0;
let shake = 0;
let stageCleared = false;
let time = 0;
let camX = 400;
let camY = 380;
let camZoom = 1;

const keys = new Set();
let jumpJustPressed = false;
let slashJustPressed = false;
let touchFastFall = false;

const stars = Array.from({ length: 80 }, () => ({
  x: Math.random(), y: Math.random() * 0.65,
  r: 0.8 + Math.random() * 1.4, phase: Math.random() * Math.PI * 2, speed: 1.5 + Math.random() * 2.5,
}));
const petals = Array.from({ length: 38 }, () => ({
  x: Math.random() * 1400, y: Math.random() * 800,
  vx: -160 + Math.random() * 70, vy: 18 + Math.random() * 30, size: 3 + Math.random() * 3.5,
}));

let particles = [];
let slashEffects = [];
let orbs = [];
let gunners = [];
let bullets = [];

const player = {
  x: 140, y: 540, w: 24, h: 34,
  vx: 544, vy: 0,
  active: false, dead: false, grounded: false,
  airJumps: 1, coyote: 0, jumpBuffer: 0,
  slashTimer: 0, slashCd: 0,
  flipAngle: 0, flipping: false,
  scaleX: 1, scaleY: 1,
  afterimages: [], ghostTimer: 0,
  scarf: Array.from({ length: 10 }, (_, i) => ({ x: 140 - i * 6, y: 516 })),
};

function loadSave() {
  try {
    const raw = JSON.parse(localStorage.getItem(SAVE_KEY) || '{}');
    currentIdx = Math.max(0, Math.min(LEVELS.length - 1, raw.unlockedIdx || 0));
  } catch {
    currentIdx = 0;
  }
}

function saveUnlocked(idx) {
  try {
    const raw = JSON.parse(localStorage.getItem(SAVE_KEY) || '{}');
    if (idx > (raw.unlockedIdx || 0)) {
      raw.unlockedIdx = Math.min(LEVELS.length - 1, idx);
      localStorage.setItem(SAVE_KEY, JSON.stringify(raw));
    }
  } catch {}
}

function showMenu() {
  player.active = false;
  respawnTimer = -1;
  sfx.setProgress(0);
  playBtn.textContent = currentIdx <= 0 ? 'PLAY' : 'CONTINUE';
  menuOverlay.classList.remove('hidden');
  clearOverlay.classList.add('hidden');
}

function startStage(idx, resetAttempts) {
  currentIdx = idx;
  if (resetAttempts) attempt = 1;
  stageCleared = false;
  respawnTimer = -1;
  hitstopTimer = 0;
  slashedCount = 0;
  comboCount = 0;
  comboTimer = 0;

  const lvl = LEVELS[idx];
  stageLabel.textContent = `Stage ${lvl.id}: ${lvl.name}`;
  attemptLabel.textContent = `Attempt #${attempt}`;
  slashLabel.textContent = 'Slashed: 0';
  progressBar.style.width = '0%';
  progressLabel.textContent = '0%';

  menuOverlay.classList.add('hidden');
  clearOverlay.classList.add('hidden');

  particles = [];
  slashEffects = [];
  bullets = [];
  orbs = lvl.orbs.map((o) => ({ x: o.x, y: o.y, used: false }));
  gunners = lvl.gunners.map((g) => ({
    x: g.x, y: g.y, rate: g.rate || 1.25, cd: 0.30,
    telegraph: 0, muzzleFlash: 0, slashed: false, slashAnim: 0,
    aimX: -1, aimY: 0,
  }));

  player.x = 140;
  player.y = 540;
  player.vx = lvl.speed;
  player.vy = 0;
  player.dead = false;
  player.active = true;
  player.grounded = false;
  player.airJumps = 1;
  player.coyote = 0;
  player.jumpBuffer = 0;
  player.slashTimer = 0;
  player.slashCd = 0;
  player.flipAngle = 0;
  player.flipping = false;
  player.scaleX = 1;
  player.scaleY = 1;
  player.afterimages = [];
  player.scarf = Array.from({ length: 10 }, (_, i) => ({ x: 140 - i * 6, y: 516 }));

  camX = player.x + 290;
  camY = 380;
  camZoom = 1;

  sfx.unlock();
  sfx.setStage(lvl.id);
  sfx.setProgress(0);
}

function spawnBurst(x, y, color, count, maxSpd = 260) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 90 + Math.random() * (maxSpd - 90);
    particles.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 80,
      color,
      size: 2.5 + Math.random() * 3,
      life: 0.25 + Math.random() * 0.25,
      maxLife: 0.5,
    });
  }
}

function killPlayer() {
  if (player.dead) return;
  player.dead = true;
  player.active = false;
  shake = 14;
  sfx.death();
  spawnBurst(player.x, player.y - 16, '#ef4444', 24, 280);
  respawnTimer = 0.55;
}

function onStageClear() {
  stageCleared = true;
  player.active = false;
  sfx.win();
  if (currentIdx + 1 < LEVELS.length) saveUnlocked(currentIdx + 1);
  progressBar.style.width = '100%';
  progressLabel.textContent = '100%';

  const isFinal = currentIdx + 1 >= LEVELS.length;
  if (isFinal) {
    clearTitle.textContent = 'YOU COMPLETED THE GAME!';
    clearStats.textContent = `Every shadow trial conquered!\nAttempts: ${attempt}   •   Enemies Slashed: ${slashedCount}`;
    replayBtn.textContent = 'Play From Stage 1';
    nextBtn.style.display = 'none';
    spawnBurst(player.x, player.y - 30, '#facc15', 36, 420);
    spawnBurst(player.x - 90, player.y - 80, '#38bdf8', 28, 380);
    spawnBurst(player.x + 90, player.y - 80, '#f472b6', 28, 380);
  } else {
    clearTitle.textContent = `${LEVELS[currentIdx].name} Cleared!`;
    clearStats.textContent = `Attempts: ${attempt}   •   Enemies Slashed: ${slashedCount}`;
    replayBtn.textContent = 'Replay';
    nextBtn.style.display = 'inline-block';
  }
  clearOverlay.classList.remove('hidden');
}

function aabb(ax, ay, aw, ah, bx, by, bw, bh) {
  return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
}

function deflectBullet(b) {
  b.deflected = true;
  b.life = 1.2;

  // Aim deflected shot back toward the nearest live gunner ahead
  let target = null;
  let bestDist = Infinity;
  for (const g of gunners) {
    if (!g.slashed && g.x > b.x - 10) {
      const d = Math.hypot(g.x - b.x, (g.y - 22) - b.y);
      if (d < 900 && d < bestDist) {
        bestDist = d;
        target = g;
      }
    }
  }
  if (target) {
    const dx = target.x - b.x;
    const dy = (target.y - 22) - b.y;
    const len = Math.hypot(dx, dy) || 1;
    const spd = 1080;
    b.vx = (dx / len) * spd;
    b.vy = (dy / len) * spd;
  } else {
    b.vx = Math.abs(b.vx) * 2.2 + 400;
    b.vy = -b.vy * 0.5;
  }

  comboCount++;
  comboTimer = 2.6;
  shake = 3;
  hitstopTimer = 0.020;
  camZoom = 1.015;
  slashLabel.textContent = `Slashed: ${slashedCount} (x${comboCount} DEFLECT!)`;
  slashEffects.push({ x: b.x, y: b.y, life: 0.20, maxLife: 0.20, radius: 36, color: '#4dd4ff' });
  spawnBurst(b.x, b.y, '#38bdf8', 8, 200);
  sfx.deflect();
}

function update(dt) {
  time += dt;
  const lvl = LEVELS[currentIdx];

  if (comboTimer > 0) {
    comboTimer -= dt;
    if (comboTimer <= 0) comboCount = 0;
  }

  for (const p of petals) {
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    if (p.x < -20) p.x = 1420;
    if (p.y > 820) { p.y = -20; p.x = Math.random() * 1400; }
  }

  for (let i = particles.length - 1; i >= 0; i--) {
    const pt = particles[i];
    pt.x += pt.vx * dt;
    pt.y += pt.vy * dt;
    pt.vy += 600 * dt;
    pt.life -= dt;
    if (pt.life <= 0) particles.splice(i, 1);
  }

  for (let i = slashEffects.length - 1; i >= 0; i--) {
    slashEffects[i].life -= dt;
    if (slashEffects[i].life <= 0) slashEffects.splice(i, 1);
  }

  if (shake > 0) shake = Math.max(0, shake - dt * 36);
  camZoom += (1 - camZoom) * Math.min(1, dt * 12);

  if (respawnTimer > 0) {
    respawnTimer -= dt;
    if (respawnTimer <= 0) {
      attempt++;
      startStage(currentIdx, false);
    }
    return;
  }

  if (hitstopTimer > 0) {
    hitstopTimer -= dt;
    return;
  }

  if (!player.active || player.dead) return;

  // Player physics
  for (let i = player.afterimages.length - 1; i >= 0; i--) {
    player.afterimages[i].alpha -= dt * 6;
    if (player.afterimages[i].alpha <= 0) player.afterimages.splice(i, 1);
  }
  player.ghostTimer -= dt;
  if ((!player.grounded || player.slashTimer > 0) && player.ghostTimer <= 0) {
    player.ghostTimer = 0.045;
    player.afterimages.push({ x: player.x, y: player.y, alpha: 0.55 });
  }

  if (jumpJustPressed) player.jumpBuffer = 0.12;
  else player.jumpBuffer = Math.max(0, player.jumpBuffer - dt);

  if (player.grounded) {
    player.coyote = 0.09;
    player.airJumps = 1;
    player.flipping = false;
    player.flipAngle = 0;
  } else {
    player.coyote = Math.max(0, player.coyote - dt);
  }

  // Cyan Orb activation
  if (jumpJustPressed && !player.grounded) {
    for (const ob of orbs) {
      if (!ob.used && Math.hypot(player.x - ob.x, (player.y - 17) - ob.y) < 38) {
        ob.used = true;
        player.vy = -820;
        player.airJumps = 1;
        player.flipping = true;
        player.flipAngle = 0;
        player.scaleX = 0.78;
        player.scaleY = 1.25;
        player.jumpBuffer = 0;
        sfx.boost();
        spawnBurst(ob.x, ob.y, '#38bdf8', 12, 220);
        break;
      }
    }
  }

  player.vy += GRAVITY * dt;
  const fastFall = touchFastFall || keys.has('KeyS') || keys.has('ArrowDown');
  if (fastFall && !player.grounded) {
    player.vy += FAST_FALL_ACCEL * dt;
  }

  if (player.jumpBuffer > 0) {
    if (player.coyote > 0) {
      player.vy = JUMP_VEL;
      player.coyote = 0;
      player.jumpBuffer = 0;
      player.grounded = false;
      player.scaleX = 0.76;
      player.scaleY = 1.28;
      sfx.jump();
    } else if (player.airJumps > 0) {
      player.airJumps--;
      player.vy = DOUBLE_JUMP_VEL;
      player.jumpBuffer = 0;
      player.flipping = true;
      player.flipAngle = 0;
      player.scaleX = 0.84;
      player.scaleY = 1.20;
      sfx.doubleJump();
    }
  }

  player.slashCd = Math.max(0, player.slashCd - dt);
  if (slashJustPressed && player.slashCd <= 0) {
    player.slashTimer = SLASH_DURATION;
    player.slashCd = SLASH_COOLDOWN;
    player.scaleX = 1.28;
    player.scaleY = 0.82;
    sfx.slash();
  }
  if (player.slashTimer > 0) {
    player.slashTimer -= dt;
    const sx = player.x + 52 - 59;
    const sy = player.y - 18 - 46;
    for (const g of gunners) {
      if (!g.slashed && aabb(sx, sy, 118, 92, g.x - 16, g.y - 42, 32, 42)) {
        g.slashed = true;
        g.slashAnim = 0;
        slashedCount++;
        comboCount++;
        comboTimer = 2.6;
        shake = 4;
        hitstopTimer = 0.025;
        camZoom = 1.018;
        slashLabel.textContent = `Slashed: ${slashedCount} (x${Math.max(1, comboCount)})`;
        slashEffects.push({ x: g.x, y: g.y - 22, life: 0.24, maxLife: 0.24, radius: 58, color: '#4dd4ff' });
        spawnBurst(g.x, g.y - 22, '#fbbf24', 10, 220);
        sfx.kill();
      }
    }
    for (const b of bullets) {
      if (!b.deflected && aabb(sx, sy, 118, 92, b.x - 8, b.y - 8, 16, 16)) {
        deflectBullet(b);
      }
    }
  }

  player.scaleX += (1 - player.scaleX) * Math.min(1, dt * 14);
  player.scaleY += (1 - player.scaleY) * Math.min(1, dt * 14);
  if (player.flipping) {
    player.flipAngle += dt * 19;
    if (player.flipAngle >= Math.PI * 2) {
      player.flipAngle = 0;
      player.flipping = false;
    }
  }

  // Horizontal move & wall-crash check (7px top-edge forgiveness)
  player.x += player.vx * dt;
  const px0 = player.x - player.w / 2;
  const py0 = player.y - player.h;
  for (const s of lvl.solids) {
    if (aabb(px0, py0, player.w, player.h, s.x, s.y, s.w, s.h)) {
      const overlapTop = player.y - s.y;
      if (overlapTop > 0 && overlapTop <= 7 && player.vy >= -150) {
        player.y = s.y;
        player.vy = 0;
        player.grounded = true;
      } else {
        killPlayer();
        return;
      }
    }
  }

  // Vertical move
  const wasGrounded = player.grounded;
  player.y += player.vy * dt;
  player.grounded = false;
  const px1 = player.x - player.w / 2;
  const py1 = player.y - player.h;
  for (const s of lvl.solids) {
    if (aabb(px1, py1, player.w, player.h, s.x, s.y, s.w, s.h)) {
      if (player.vy >= 0) {
        player.y = s.y;
        player.vy = 0;
        player.grounded = true;
        if (!wasGrounded) {
          player.scaleX = 1.24;
          player.scaleY = 0.78;
        }
      } else {
        player.y = s.y + s.h + player.h;
        player.vy = 0;
      }
    }
  }

  if (player.y > 900) {
    killPlayer();
    return;
  }

  // Spikes
  for (const sp of lvl.spikes) {
    if (aabb(player.x - 10, player.y - 32, 20, 32, sp.x + 5, sp.y + 4, sp.w - 10, 12)) {
      killPlayer();
      return;
    }
  }

  // Gold Jump Pads
  for (const pd of lvl.pads) {
    if (aabb(player.x - 12, player.y - 34, 24, 34, pd.x, pd.y, pd.w, 14)) {
      player.vy = -1020;
      player.grounded = false;
      player.airJumps = 1;
      player.flipping = true;
      player.flipAngle = 0;
      player.scaleX = 0.74;
      player.scaleY = 1.32;
      sfx.boost();
      spawnBurst(pd.x + pd.w / 2, pd.y, '#fbbf24', 14, 220);
    }
  }

  // Gunners & Bullets
  for (const g of gunners) {
    if (g.muzzleFlash > 0) g.muzzleFlash = Math.max(0, g.muzzleFlash - dt * 8);
    if (g.slashed) {
      g.slashAnim += dt;
      continue;
    }
    const dist = Math.hypot(g.x - player.x, g.y - player.y);
    if (dist <= 760 && player.x < g.x + 40) {
      const dx = player.x - (g.x - 14);
      const dy = (player.y - 18) - (g.y - 25);
      const len = Math.hypot(dx, dy) || 1;
      g.aimX = dx / len;
      g.aimY = dy / len;
      g.cd -= dt;
      if (g.cd <= 0.28 && g.cd > 0) g.telegraph = 1 - g.cd / 0.28;
      else if (g.cd <= 0) {
        bullets.push({ x: g.x - 22, y: g.y - 25, vx: g.aimX * 490, vy: g.aimY * 490, deflected: false, life: 3 });
        g.muzzleFlash = 1;
        g.cd = g.rate;
        g.telegraph = 0;
        sfx.shoot();
      }
    } else {
      g.telegraph = 0;
    }

    if (aabb(player.x - 12, player.y - 34, 24, 34, g.x - 16, g.y - 42, 32, 42)) {
      if (player.slashTimer > 0) {
        g.slashed = true;
        g.slashAnim = 0;
        slashedCount++;
        sfx.kill();
      } else {
        killPlayer();
        return;
      }
    }
  }

  for (let i = bullets.length - 1; i >= 0; i--) {
    const b = bullets[i];
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.life -= dt;
    if (b.life <= 0) {
      bullets.splice(i, 1);
      continue;
    }
    if (b.deflected) {
      let hitEnemy = false;
      for (const g of gunners) {
        if (!g.slashed && aabb(b.x - 10, b.y - 10, 20, 20, g.x - 18, g.y - 44, 36, 44)) {
          g.slashed = true;
          g.slashAnim = 0;
          slashedCount++;
          comboCount++;
          comboTimer = 2.6;
          shake = 4;
          hitstopTimer = 0.025;
          camZoom = 1.018;
          slashLabel.textContent = `Slashed: ${slashedCount} (x${Math.max(1, comboCount)})`;
          slashEffects.push({ x: g.x, y: g.y - 22, life: 0.24, maxLife: 0.24, radius: 58, color: '#4dd4ff' });
          spawnBurst(g.x, g.y - 22, '#38bdf8', 12, 240);
          sfx.kill();
          hitEnemy = true;
          break;
        }
      }
      if (hitEnemy) {
        bullets.splice(i, 1);
        continue;
      }
    } else if (Math.hypot(b.x - player.x, b.y - (player.y - 17)) < 16) {
      if (player.slashTimer > 0) {
        deflectBullet(b);
      } else {
        killPlayer();
        return;
      }
    }
  }

  // Scarf physics
  player.scarf[0].x = player.x - 8;
  player.scarf[0].y = player.y - 25;
  for (let i = 1; i < player.scarf.length; i++) {
    const prev = player.scarf[i - 1];
    const curr = player.scarf[i];
    curr.y += (32 + Math.sin(time * 14 + i) * 18) * dt;
    curr.x -= 85 * dt;
    const dx = curr.x - prev.x;
    const dy = curr.y - prev.y;
    const d = Math.hypot(dx, dy) || 1;
    if (d > 6.5) {
      curr.x = prev.x + (dx / d) * 6.5;
      curr.y = prev.y + (dy / d) * 6.5;
    }
  }

  // Camera & progress
  camX = player.x + 290;
  const targetCamY = Math.max(260, Math.min(420, player.y - 70));
  camY += (targetCamY - camY) * Math.min(1, dt * 7);

  const pct = Math.max(0, Math.min(1, (player.x - 140) / (lvl.goalX - 140)));
  sfx.setProgress(pct);
  const pctInt = Math.round(pct * 100);
  progressBar.style.width = `${pctInt}%`;
  progressLabel.textContent = `${pctInt}%`;

  if (player.x >= lvl.goalX) {
    onStageClear();
  }
}

function render() {
  const lvl = LEVELS[currentIdx];
  const W = 1280;
  const H = 720;
  const sx = shake > 0 ? (Math.random() - 0.5) * shake * 2 : 0;
  const sy = shake > 0 ? (Math.random() - 0.5) * shake * 2 : 0;

  ctx.save();
  ctx.translate(W / 2, H / 2);
  ctx.scale(camZoom, camZoom);
  ctx.translate(-W / 2, -H / 2);

  // Sky Gradient
  const skyGrad = ctx.createLinearGradient(0, 0, 0, H);
  skyGrad.addColorStop(0, lvl.skyTop);
  skyGrad.addColorStop(1, lvl.skyBottom);
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, W, H);

  // Stars
  for (const st of stars) {
    const a = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(time * st.speed + st.phase));
    ctx.fillStyle = `rgba(226, 232, 240, ${a})`;
    ctx.beginPath();
    ctx.arc(st.x * W, st.y * H, st.r, 0, Math.PI * 2);
    ctx.fill();
  }

  // Moon
  const moonX = W * 0.5 + 340 - camX * 0.03;
  const moonY = H * 0.5 - 160;
  ctx.fillStyle = 'rgba(254, 246, 195, 0.08)';
  ctx.beginPath();
  ctx.arc(moonX, moonY, 110, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#fef6c3';
  ctx.beginPath();
  ctx.arc(moonX, moonY, 46, 0, Math.PI * 2);
  ctx.fill();

  // Parallax Pagoda / Cyber Skyline (no jagged shadow tree spikes)
  const midStep = 170;
  const midStart = Math.floor((camX - 950) / midStep) * midStep;
  for (let i = 0; i < 12; i++) {
    const bx = midStart + i * midStep - camX * 0.18 - (camX - W / 2);
    const bh = 135 + Math.abs(Math.cos((midStart + i * midStep) * 0.019) * 170) % 150;
    const drawX = bx + camX - W / 2;
    const screenX = (midStart + i * midStep) - camX * 0.18;
    const sxPos = screenX - (camX - W / 2) * 0.82;
    ctx.fillStyle = 'rgba(15, 20, 43, 0.72)';
    ctx.fillRect(sxPos, H - bh, 118, bh + 150);
    ctx.fillStyle = 'rgba(20, 26, 54, 0.85)';
    ctx.beginPath();
    ctx.moveTo(sxPos - 12, H - bh + 8);
    ctx.lineTo(sxPos + 59, H - bh - 14);
    ctx.lineTo(sxPos + 130, H - bh + 8);
    ctx.closePath();
    ctx.fill();
  }

  // World Space
  ctx.save();
  ctx.translate(W / 2 - camX + sx, H / 2 - camY + sy);

  // Solids
  for (const s of lvl.solids) {
    if (s.x + s.w < camX - 850 || s.x > camX + 950) continue;
    if (s.kind === 'ceiling') {
      ctx.fillStyle = 'rgba(8, 10, 20, 0.55)';
      ctx.fillRect(s.x + 12, s.y + s.h, s.w - 24, 180);
      ctx.fillStyle = '#121729';
      ctx.fillRect(s.x, s.y, s.w, s.h);
      ctx.strokeStyle = lvl.tunnelTrim;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(s.x, s.y + s.h);
      ctx.lineTo(s.x + s.w, s.y + s.h);
      ctx.stroke();
    } else if (s.kind === 'building') {
      ctx.fillStyle = '#141930';
      ctx.fillRect(s.x, s.y, s.w, s.h);
      ctx.strokeStyle = lvl.roofTrim;
      ctx.lineWidth = 4.5;
      ctx.beginPath();
      ctx.moveTo(s.x - 8, s.y + 2);
      ctx.lineTo(s.x + s.w + 8, s.y + 2);
      ctx.stroke();
      ctx.fillStyle = lvl.windowCol;
      for (let wx = s.x + 18; wx < s.x + s.w - 22; wx += 28) {
        for (let wy = s.y + 24; wy < Math.min(s.y + s.h - 24, s.y + 130); wy += 28) {
          ctx.fillRect(wx, wy, 8, 12);
        }
      }
    } else {
      ctx.fillStyle = '#0f1729';
      ctx.fillRect(s.x, s.y, s.w, s.h);
      ctx.strokeStyle = lvl.groundTrim;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(s.x, s.y + 1.5);
      ctx.lineTo(s.x + s.w, s.y + 1.5);
      ctx.stroke();
    }
  }

  // Spikes
  for (const sp of lvl.spikes) {
    const count = Math.max(1, Math.floor(sp.w / 16));
    const step = sp.w / count;
    for (let i = 0; i < count; i++) {
      const x0 = sp.x + i * step;
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath();
      ctx.moveTo(x0, sp.y + 16);
      ctx.lineTo(x0 + step * 0.5, sp.y);
      ctx.lineTo(x0 + step, sp.y + 16);
      ctx.closePath();
      ctx.fill();
    }
  }

  // Gold Pads
  ctx.fillStyle = '#facc15';
  for (const pd of lvl.pads) {
    ctx.fillRect(pd.x, pd.y, pd.w, 12);
  }

  // Cyan Orbs
  for (const ob of orbs) {
    ctx.fillStyle = 'rgba(56, 189, 248, 0.22)';
    ctx.beginPath();
    ctx.arc(ob.x, ob.y, 20 + Math.sin(time * 6) * 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 3.5;
    ctx.beginPath();
    ctx.arc(ob.x, ob.y, 16, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(ob.x, ob.y, 7, 0, Math.PI * 2);
    ctx.fill();
  }

  // Crimson Torii Goal
  const gx = lvl.goalX;
  ctx.fillStyle = 'rgba(250, 204, 21, 0.14)';
  ctx.beginPath();
  ctx.arc(gx + 32, 470, 65, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ef4444';
  ctx.fillRect(gx, 410, 10, 130);
  ctx.fillRect(gx + 54, 410, 10, 130);
  ctx.fillRect(gx - 10, 400, 84, 12);
  ctx.fillStyle = '#fde047';
  ctx.beginPath();
  ctx.arc(gx + 32, 460 + Math.sin(time * 4) * 5, 14, 0, Math.PI * 2);
  ctx.fill();

  // Gunners
  for (const g of gunners) {
    if (g.slashed) {
      if (g.slashAnim > 0.55) continue;
      const t = Math.min(1, g.slashAnim / 0.55);
      const a = Math.max(0, 1 - Math.pow(t, 1.4));
      const split = t * 140;
      ctx.save();
      ctx.globalAlpha = a;
      ctx.strokeStyle = 'rgba(77, 212, 255, 0.45)';
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.arc(g.x, g.y - 22, 14 + t * 50, 0, Math.PI * 2);
      ctx.stroke();
      ctx.save();
      ctx.translate(g.x + split * 0.45, g.y - 32 - split * 0.55);
      ctx.rotate(t * 1.4);
      ctx.fillStyle = '#38405c';
      ctx.fillRect(-12, -10, 24, 20);
      ctx.fillStyle = '#ef4444';
      ctx.fillRect(-13, -10, 26, 6);
      ctx.restore();
      ctx.save();
      ctx.translate(g.x - split * 0.35, g.y - 10 + split * 0.3);
      ctx.rotate(-t * 1.0);
      ctx.fillStyle = '#262b42';
      ctx.fillRect(-12, -10, 24, 20);
      ctx.restore();
      ctx.restore();
      continue;
    }
    ctx.fillStyle = '#1a1f30';
    ctx.fillRect(g.x - 10, g.y - 14, 7, 14);
    ctx.fillRect(g.x + 3, g.y - 14, 7, 14);
    ctx.fillStyle = '#262e47';
    ctx.fillRect(g.x - 12, g.y - 38, 24, 26);
    ctx.fillStyle = '#dc2626';
    ctx.fillRect(g.x - 13, g.y - 38, 26, 6);
    ctx.fillStyle = '#1a1f33';
    ctx.beginPath();
    ctx.arc(g.x, g.y - 42, 10.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(g.x - 10, g.y - 45, 13, 4.5);
    ctx.fillStyle = '#73859e';
    ctx.fillRect(g.x - 26, g.y - 28, 22, 5.5);
  }

  // Bullets
  for (const b of bullets) {
    ctx.fillStyle = b.deflected ? '#38bdf8' : '#ef4444';
    ctx.beginPath();
    ctx.arc(b.x, b.y, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(b.x, b.y, 2.5, 0, Math.PI * 2);
    ctx.fill();
  }

  // Player Scarf
  if (!player.dead) {
    ctx.strokeStyle = '#ef4444';
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (let i = 1; i < player.scarf.length; i++) {
      ctx.lineWidth = Math.max(1.5, 8 * (1 - i / player.scarf.length));
      ctx.beginPath();
      ctx.moveTo(player.scarf[i - 1].x, player.scarf[i - 1].y);
      ctx.lineTo(player.scarf[i].x, player.scarf[i].y);
      ctx.stroke();
    }
  }

  // Player Afterimages
  for (const img of player.afterimages) {
    ctx.fillStyle = `rgba(56, 189, 248, ${img.alpha * 0.28})`;
    ctx.beginPath();
    ctx.arc(img.x, img.y - 17, 14, 0, Math.PI * 2);
    ctx.fill();
  }

  // Cat Ninja Player
  if (!player.dead) {
    ctx.save();
    ctx.translate(player.x, player.y - 17);
    ctx.rotate(player.flipAngle);
    ctx.scale(player.scaleX, player.scaleY);

    const wag = Math.sin(time * 13) * 5;
    ctx.strokeStyle = '#242947';
    ctx.lineWidth = 4.5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(-9, 8);
    ctx.lineTo(-22, -2 + wag);
    ctx.stroke();

    ctx.fillStyle = '#121729';
    ctx.beginPath();
    ctx.arc(0, 4, 11.5, 0, Math.PI * 2);
    ctx.arc(0, -7, 12, 0, Math.PI * 2);
    ctx.fill();

    // Ears
    ctx.beginPath();
    ctx.moveTo(-11, -13); ctx.lineTo(-14, -27); ctx.lineTo(-2, -16);
    ctx.moveTo(2, -16); ctx.lineTo(14, -27); ctx.lineTo(11, -13);
    ctx.fill();

    // Headband
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-11, -12);
    ctx.lineTo(11, -12);
    ctx.stroke();

    // Glowing Amber Eyes
    ctx.fillStyle = '#facc15';
    ctx.beginPath();
    ctx.arc(5.5, -7, 3, 0, Math.PI * 2);
    ctx.arc(-1.5, -7, 2.4, 0, Math.PI * 2);
    ctx.fill();

    // Sheathed Katana or Sweeping Slash Arc
    if (player.slashTimer <= 0) {
      ctx.strokeStyle = '#bfd1eb';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(-10, 6);
      ctx.lineTo(-20, -22);
      ctx.stroke();
    } else {
      const prog = 1 - Math.max(0, Math.min(1, player.slashTimer / SLASH_DURATION));
      const a = Math.max(0, 1 - prog * 0.85);
      const ang = -1.5 + 2.65 * prog;
      ctx.strokeStyle = `rgba(255, 255, 255, ${a})`;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(6, -2);
      ctx.lineTo(12 + Math.cos(ang) * 62, -4 + Math.sin(ang) * 62);
      ctx.stroke();
      ctx.strokeStyle = `rgba(77, 212, 255, ${a * 0.85})`;
      ctx.lineWidth = 10 * a;
      ctx.beginPath();
      ctx.arc(14, -4, 48 + prog * 14, -1.25, 1.15);
      ctx.stroke();
    }
    ctx.restore();
  }

  // Subtle Enemy Slash Effects
  for (const se of slashEffects) {
    const prog = 1 - se.life / se.maxLife;
    const sa = Math.max(0, 1 - prog);
    ctx.strokeStyle = `rgba(77, 212, 255, ${sa * 0.40})`;
    ctx.lineWidth = 2.2 * sa;
    ctx.beginPath();
    ctx.arc(se.x, se.y, 12 + prog * se.radius, 0, Math.PI * 2);
    ctx.stroke();
    const cutA = Math.max(0, 1 - prog * 1.7);
    if (cutA > 0) {
      const reach = se.radius * (0.7 + prog * 0.2);
      ctx.strokeStyle = `rgba(77, 212, 255, ${cutA * 0.70})`;
      ctx.lineWidth = 3.6 * cutA;
      ctx.beginPath();
      ctx.moveTo(se.x - reach, se.y + reach * 0.55);
      ctx.lineTo(se.x + reach, se.y - reach * 0.55);
      ctx.stroke();
    }
  }

  // Particles
  for (const pt of particles) {
    ctx.globalAlpha = Math.max(0, pt.life / pt.maxLife);
    ctx.fillStyle = pt.color;
    ctx.beginPath();
    ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;

  ctx.restore();

  // Drifting Sakura Petals (screen space)
  for (const p of petals) {
    ctx.fillStyle = 'rgba(252, 163, 176, 0.55)';
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size * 0.65, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.restore();
}

window.addEventListener('keydown', (e) => {
  if (['Space', 'ArrowUp', 'ArrowDown', 'KeyW', 'KeyS'].includes(e.code)) e.preventDefault();
  if (!keys.has(e.code)) {
    if ((e.code === 'Space' || e.code === 'Enter') && !menuOverlay.classList.contains('hidden')) {
      startStage(currentIdx, true);
      return;
    }
    if (e.code === 'Space' || e.code === 'KeyW' || e.code === 'ArrowUp') jumpJustPressed = true;
    if (e.code === 'KeyJ' || e.code === 'KeyK' || e.code === 'ShiftLeft' || e.code === 'ShiftRight') slashJustPressed = true;
    if (e.code === 'KeyR' && !menuOverlay.classList.contains('hidden') === false) startStage(currentIdx, false);
  }
  keys.add(e.code);
});
window.addEventListener('keyup', (e) => keys.delete(e.code));
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
canvas.addEventListener('mousedown', (e) => {
  if (e.button === 2) slashJustPressed = true;
  else if (e.button === 0 && player.active) jumpJustPressed = true;
});

const btnJump = document.getElementById('btn-jump');
const btnSlash = document.getElementById('btn-slash');
const btnDrop = document.getElementById('btn-drop');

function enableTouchUI() {
  document.body.classList.add('is-touch');
  sfx.unlock();
}

window.addEventListener('touchstart', enableTouchUI, { passive: true, once: true });

btnJump.addEventListener('touchstart', (e) => {
  e.preventDefault();
  enableTouchUI();
  btnJump.classList.add('pressed');
  if (player.active) jumpJustPressed = true;
}, { passive: false });
btnJump.addEventListener('touchend', (e) => { e.preventDefault(); btnJump.classList.remove('pressed'); }, { passive: false });
btnJump.addEventListener('touchcancel', () => btnJump.classList.remove('pressed'));

btnSlash.addEventListener('touchstart', (e) => {
  e.preventDefault();
  enableTouchUI();
  btnSlash.classList.add('pressed');
  if (player.active) slashJustPressed = true;
}, { passive: false });
btnSlash.addEventListener('touchend', (e) => { e.preventDefault(); btnSlash.classList.remove('pressed'); }, { passive: false });
btnSlash.addEventListener('touchcancel', () => btnSlash.classList.remove('pressed'));

btnDrop.addEventListener('touchstart', (e) => {
  e.preventDefault();
  enableTouchUI();
  btnDrop.classList.add('pressed');
  touchFastFall = true;
}, { passive: false });
btnDrop.addEventListener('touchend', (e) => { e.preventDefault(); btnDrop.classList.remove('pressed'); touchFastFall = false; }, { passive: false });
btnDrop.addEventListener('touchcancel', () => { btnDrop.classList.remove('pressed'); touchFastFall = false; });

canvas.addEventListener('touchstart', (e) => {
  if (!player.active) return;
  e.preventDefault();
  enableTouchUI();
  for (const t of e.changedTouches) {
    if (t.clientX >= window.innerWidth * 0.45) jumpJustPressed = true;
    else slashJustPressed = true;
  }
}, { passive: false });

function bindTap(el, fn) {
  let touched = false;
  el.addEventListener('touchend', (e) => {
    e.preventDefault();
    touched = true;
    fn();
  }, { passive: false });
  el.addEventListener('click', () => {
    if (touched) { touched = false; return; }
    fn();
  });
}

bindTap(playBtn, () => startStage(currentIdx, true));
bindTap(replayBtn, () => {
  const target = (currentIdx + 1 >= LEVELS.length && stageCleared) ? 0 : currentIdx;
  startStage(target, true);
});
bindTap(nextBtn, () => {
  if (currentIdx + 1 < LEVELS.length) startStage(currentIdx + 1, true);
});
bindTap(menuBtn, () => {
  menuBtn.blur();
  showMenu();
});
bindTap(muteBtn, () => {
  const m = sfx.toggleMute();
  muteBtn.textContent = m ? 'Sound: OFF' : 'Sound: ON';
  muteBtn.blur();
});

loadSave();
showMenu();

let last = performance.now();
function loop(now) {
  const dt = Math.min(0.033, (now - last) / 1000);
  last = now;
  update(dt);
  render();
  jumpJustPressed = false;
  slashJustPressed = false;
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);
