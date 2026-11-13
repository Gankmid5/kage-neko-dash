// Studio-grade Web Audio API procedural synthwave & SFX engine for Kage-Neko Dash
// Mirrors Godot's SoundFX.gd: 64-step chord progressions, 4 dynamic intensity tiers,
// filtered supersaw bass, sidechain ducking, lush minor pad chords, stereo-echo lead,
// noise-snapped drums/hi-hats, and multi-layered harmonic SFX.

const TRACKS = {
  1: { bpm: 148, roots: [73.42, 58.27, 65.41, 55.00], lead: [587.33,0,659.25,0,698.46,0,880,0,698.46,0,659.25,0,587.33,0,523.25,0,587.33,0,698.46,0,932.33,0,880,0,698.46,0,587.33,0,466.16,0,523.25,0,523.25,0,659.25,0,783.99,0,1046.5,0,880,0,783.99,0,659.25,0,587.33,0,440,0,523.25,0,659.25,0,880,0,783.99,0,659.25,0,587.33,523.25,440,0] },
  2: { bpm: 154, roots: [82.41, 87.31, 98.00, 73.42], lead: [659.25,0,698.46,0,783.99,0,987.77,0,783.99,0,698.46,0,659.25,0,587.33,0,698.46,0,880,0,1046.5,0,880,0,698.46,0,659.25,0,587.33,0,523.25,0,783.99,0,987.77,0,1174.7,0,987.77,0,783.99,0,698.46,0,659.25,0,587.33,0,587.33,0,659.25,0,698.46,0,880,0,783.99,0,698.46,0,659.25,587.33,493.88,0] },
  3: { bpm: 160, roots: [92.50, 73.42, 82.41, 69.30], lead: [739.99,0,880,0,1108.7,0,987.77,0,880,0,739.99,0,659.25,0,587.33,0,587.33,0,739.99,0,880,0,1174.7,0,1108.7,0,880,0,739.99,0,659.25,0,659.25,0,824.07,0,987.77,0,1318.5,0,1108.7,0,987.77,0,824.07,0,739.99,0,554.37,0,659.25,0,824.07,0,1108.7,0,987.77,0,824.07,0,739.99,659.25,554.37,0] },
  4: { bpm: 168, roots: [110.00, 87.31, 98.00, 82.41], lead: [880,1046.5,1318.5,0,1174.7,1046.5,880,0,880,1046.5,1318.5,0,1568,1318.5,1046.5,0,698.46,880,1046.5,0,1396.9,1318.5,1046.5,0,880,1046.5,1174.7,0,1046.5,880,698.46,0,783.99,987.77,1174.7,0,1568,1318.5,1174.7,0,987.77,1174.7,1318.5,0,1174.7,987.77,783.99,0,659.25,783.99,987.77,0,1318.5,1174.7,987.77,0,880,987.77,1046.5,0,1318.5,1174.7,987.77,0] },
  5: { bpm: 172, roots: [98.00, 77.78, 87.31, 73.42], lead: [783.99,0,932.33,0,1174.7,0,1046.5,0,932.33,0,783.99,0,698.46,0,587.33,0,622.25,0,783.99,0,932.33,0,1244.5,0,1174.7,0,932.33,0,783.99,0,622.25,0,698.46,0,880,0,1046.5,0,1396.9,0,1174.7,0,1046.5,0,880,0,698.46,0,587.33,0,698.46,0,880,0,1174.7,0,1046.5,0,880,0,783.99,698.46,587.33,0] },
  6: { bpm: 176, roots: [65.41, 103.83, 116.54, 98.00], lead: [523.25,622.25,783.99,0,1046.5,783.99,622.25,0,523.25,622.25,783.99,0,932.33,783.99,622.25,0,830.61,1046.5,1244.5,0,1046.5,830.61,622.25,0,830.61,1046.5,1244.5,0,1396.9,1244.5,1046.5,0,932.33,1174.7,1396.9,0,1174.7,932.33,698.46,0,932.33,1174.7,1396.9,0,1568,1396.9,1174.7,0,783.99,987.77,1174.7,0,1568,1396.9,1174.7,0,987.77,1174.7,1396.9,0,1568,1396.9,1174.7,0] },
  7: { bpm: 180, roots: [61.74, 65.41, 73.42, 55.00], lead: [493.88,0,523.25,0,659.25,0,783.99,0,987.77,0,783.99,0,659.25,0,523.25,0,523.25,0,659.25,0,783.99,0,1046.5,0,987.77,0,783.99,0,659.25,0,523.25,0,587.33,0,739.99,0,880,0,1174.7,0,1046.5,0,880,0,739.99,0,587.33,0,440,0,523.25,0,659.25,0,880,0,987.77,0,880,0,783.99,659.25,523.25,0] },
  8: { bpm: 184, roots: [69.30, 55.00, 61.74, 103.83], lead: [554.37,659.25,830.61,0,1108.7,830.61,659.25,0,554.37,659.25,830.61,0,987.77,830.61,659.25,0,440,554.37,659.25,0,880,659.25,554.37,0,440,554.37,659.25,0,830.61,659.25,554.37,0,493.88,622.25,739.99,0,987.77,739.99,622.25,0,493.88,622.25,739.99,0,932.33,739.99,622.25,0,830.61,987.77,1244.5,0,1661.2,1480,1244.5,0,987.77,1244.5,1480,0,1661.2,1480,1244.5,0] },
  9: { bpm: 190, roots: [73.42, 58.27, 98.00, 110.00], lead: [587.33,698.46,880,0,1174.7,880,698.46,0,587.33,698.46,880,0,1046.5,880,698.46,0,466.16,587.33,698.46,0,932.33,698.46,587.33,0,466.16,587.33,698.46,0,880,698.46,587.33,0,783.99,932.33,1174.7,0,1568,1396.9,1174.7,0,932.33,1174.7,1396.9,0,1568,1396.9,1174.7,0,880,1108.7,1318.5,0,1760,1568,1318.5,0,1108.7,1318.5,1568,0,1760,1568,1318.5,0] },
};

class SoundEngine {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.stageId = 1;
    this.progress = 0;
    this.stepIdx = 0;
    this.nextStepTime = 0;
    this.bgmRunning = false;

    // Audio graph nodes
    this.masterGain = null;
    this.sidechainBus = null;
    this.leadBus = null;
    this.noiseBuffer = null;
  }

  _initGraph(ctx) {
    // Master bus (controls mute cleanly without killing context)
    this.masterGain = ctx.createGain();
    this.masterGain.gain.setValueAtTime(this.muted ? 0 : 0.72, ctx.currentTime);
    const limiter = ctx.createDynamicsCompressor();
    limiter.threshold.setValueAtTime(-6, ctx.currentTime);
    limiter.knee.setValueAtTime(6, ctx.currentTime);
    limiter.ratio.setValueAtTime(6, ctx.currentTime);
    limiter.attack.setValueAtTime(0.003, ctx.currentTime);
    limiter.release.setValueAtTime(0.12, ctx.currentTime);
    this.masterGain.connect(limiter);
    limiter.connect(ctx.destination);

    // Sidechain ducking bus for bass & lush pad chords
    this.sidechainBus = ctx.createGain();
    this.sidechainBus.gain.setValueAtTime(1.0, ctx.currentTime);
    this.sidechainBus.connect(this.masterGain);

    // Lead bus + ~300ms stereo-style echo delay (matches SoundFX.gd DELAY_SAMPLES = 13230 @ 44.1kHz)
    this.leadBus = ctx.createGain();
    this.leadBus.gain.setValueAtTime(1.0, ctx.currentTime);

    const delay = ctx.createDelay(1.0);
    delay.delayTime.setValueAtTime(0.30, ctx.currentTime);
    const feedback = ctx.createGain();
    feedback.gain.setValueAtTime(0.36, ctx.currentTime);
    const wetGain = ctx.createGain();
    wetGain.gain.setValueAtTime(0.55, ctx.currentTime);

    this.leadBus.connect(this.masterGain);
    this.leadBus.connect(delay);
    delay.connect(feedback);
    feedback.connect(delay);

    if (ctx.createStereoPanner) {
      const panDry = ctx.createStereoPanner();
      panDry.pan.setValueAtTime(-0.08, ctx.currentTime);
      const panWet = ctx.createStereoPanner();
      panWet.pan.setValueAtTime(0.22, ctx.currentTime);
      delay.connect(wetGain);
      wetGain.connect(panWet);
      panWet.connect(this.masterGain);
    } else {
      delay.connect(wetGain);
      wetGain.connect(this.masterGain);
    }

    // Shared 1.5s white noise buffer for hats, snare snap, slash swoosh, shots, death
    const len = Math.floor(ctx.sampleRate * 1.5);
    this.noiseBuffer = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = this.noiseBuffer.getChannelData(0);
    for (let i = 0; i < len; i++) {
      data[i] = Math.random() * 2 - 1;
    }
  }

  _ensureCtx() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) {
        this.ctx = new AC();
        this._initGraph(this.ctx);
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  unlock() {
    const ctx = this._ensureCtx();
    if (ctx && !this.bgmRunning) {
      this.bgmRunning = true;
      this.nextStepTime = ctx.currentTime + 0.05;
      setInterval(() => this._scheduleBgm(), 25);
    }
  }

  setStage(id) {
    this.stageId = Math.max(1, Math.min(9, id));
    this.stepIdx = 0;
  }

  setProgress(pct) {
    this.progress = Math.max(0, Math.min(1, pct));
  }

  toggleMute() {
    this.muted = !this.muted;
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.setTargetAtTime(this.muted ? 0 : 0.72, this.ctx.currentTime, 0.015);
    }
    return this.muted;
  }

  _scheduleBgm() {
    if (this.muted || !this.ctx || this.ctx.state !== 'running') return;
    if (this.nextStepTime < this.ctx.currentTime - 0.25) {
      this.nextStepTime = this.ctx.currentTime + 0.02;
    }
    const tr = TRACKS[this.stageId] || TRACKS[1];
    const tier = this._getTier();
    const bpm = tr.bpm + (tier === 3 ? 8 : tier === 2 ? 4 : 0);
    const stepDur = 60 / bpm / 4;

    while (this.nextStepTime < this.ctx.currentTime + 0.12) {
      this._triggerStep(this.nextStepTime, this.stepIdx, tr, stepDur, tier);
      this.nextStepTime += stepDur;
      this.stepIdx = (this.stepIdx + 1) % 64;
    }
  }

  _getTier() {
    if (this.progress >= 0.75) return 3;
    if (this.progress >= 0.50) return 2;
    if (this.progress >= 0.25) return 1;
    return 0;
  }

  _triggerStep(t, step, tr, dur, tier) {
    const ctx = this.ctx;
    const s16 = step % 16;
    const bar = Math.floor(step / 16);
    const keyMult = tier === 3 ? 1.12246 : 1.0; // +2 semitones climax lift
    const rootFreq = tr.roots[bar] * keyMult;

    // 1. Punchy Analog Sub-Kick + Sidechain Pump
    const kickHit = s16 === 0 || s16 === 4 || s16 === 8 || s16 === 12 || (tier >= 2 && s16 === 14);
    if (kickHit) {
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(181, t);
      osc.frequency.exponentialRampToValueAtTime(46, t + 0.09);
      g.gain.setValueAtTime(0.42, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
      osc.connect(g);
      g.connect(this.masterGain);
      osc.start(t);
      osc.stop(t + 0.17);

      // Duck bass & pads when kick hits
      this.sidechainBus.gain.cancelScheduledValues(t);
      this.sidechainBus.gain.setValueAtTime(0.28, t);
      this.sidechainBus.gain.linearRampToValueAtTime(1.0, t + Math.min(0.15, dur * 1.4));
    }

    // 2. Snare (185Hz sine body + low-passed noise snap) from Tier 1+
    if (tier >= 1 && (s16 === 4 || s16 === 12 || (tier === 3 && step === 63))) {
      const bodyOsc = ctx.createOscillator();
      const bodyG = ctx.createGain();
      bodyOsc.type = 'sine';
      bodyOsc.frequency.setValueAtTime(185, t);
      bodyOsc.frequency.exponentialRampToValueAtTime(95, t + 0.08);
      bodyG.gain.setValueAtTime(0.16, t);
      bodyG.gain.exponentialRampToValueAtTime(0.001, t + 0.11);
      bodyOsc.connect(bodyG);
      bodyG.connect(this.masterGain);
      bodyOsc.start(t);
      bodyOsc.stop(t + 0.12);

      const nSrc = ctx.createBufferSource();
      nSrc.buffer = this.noiseBuffer;
      const nFilter = ctx.createBiquadFilter();
      nFilter.type = 'lowpass';
      nFilter.frequency.setValueAtTime(3400, t);
      const nG = ctx.createGain();
      nG.gain.setValueAtTime(0.20, t);
      nG.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
      nSrc.connect(nFilter);
      nFilter.connect(nG);
      nG.connect(this.masterGain);
      nSrc.start(t);
      nSrc.stop(t + 0.13);
    }

    // 3. Crisp High-Passed Hi-Hat (off-beat + 16th ghost hats in Tier 1+)
    let hatAmp = 0;
    if (s16 % 4 === 2) hatAmp = 0.11;
    else if (tier >= 1 && s16 % 2 === 1) hatAmp = 0.048;

    if (hatAmp > 0) {
      const hSrc = ctx.createBufferSource();
      hSrc.buffer = this.noiseBuffer;
      const hp = ctx.createBiquadFilter();
      hp.type = 'highpass';
      hp.frequency.setValueAtTime(6800, t);
      const hG = ctx.createGain();
      hG.gain.setValueAtTime(hatAmp, t);
      hG.gain.exponentialRampToValueAtTime(0.001, t + 0.045);
      hSrc.connect(hp);
      hp.connect(hG);
      hG.connect(this.masterGain);
      hSrc.start(t);
      hSrc.stop(t + 0.05);
    }

    // 4. Warm Filtered Supersaw Bass (rolling 16th-note octave groove)
    const octUp = s16 % 4 === 2 || (tier >= 2 && s16 % 4 === 3);
    const bFreq = rootFreq * (octUp ? 2.0 : 1.0);
    const bassFilter = ctx.createBiquadFilter();
    bassFilter.type = 'lowpass';
    bassFilter.frequency.setValueAtTime(480 + tier * 320, t);
    bassFilter.Q.setValueAtTime(1.6, t);

    const bassG = ctx.createGain();
    bassG.gain.setValueAtTime(0.14, t);
    bassG.gain.linearRampToValueAtTime(0.08, t + dur * 0.9);
    bassG.gain.exponentialRampToValueAtTime(0.001, t + dur * 1.05);

    const bOsc1 = ctx.createOscillator();
    const bOsc2 = ctx.createOscillator();
    bOsc1.type = 'sawtooth';
    bOsc2.type = 'sawtooth';
    bOsc1.frequency.setValueAtTime(bFreq, t);
    bOsc2.frequency.setValueAtTime(bFreq * 1.006, t);

    bOsc1.connect(bassFilter);
    bOsc2.connect(bassFilter);
    bassFilter.connect(bassG);
    bassG.connect(this.sidechainBus);

    bOsc1.start(t);
    bOsc2.start(t);
    bOsc1.stop(t + dur * 1.08);
    bOsc2.stop(t + dur * 1.08);

    // 5. Lush Pad Chords (root + minor 3rd + perfect 5th) on bar boundaries from Tier 1+
    if (tier >= 1 && s16 === 0) {
      const pRoot = rootFreq * 2.0;
      const chordRatios = [1.0, 1.1892, 1.4983];
      const barDur = dur * 16;
      const padG = ctx.createGain();
      padG.gain.setValueAtTime(0.001, t);
      padG.gain.linearRampToValueAtTime(0.042, t + 0.08);
      padG.gain.setValueAtTime(0.042, t + barDur - 0.08);
      padG.gain.exponentialRampToValueAtTime(0.001, t + barDur);
      padG.connect(this.sidechainBus);

      for (const ratio of chordRatios) {
        const pOsc = ctx.createOscillator();
        pOsc.type = 'sine';
        pOsc.frequency.setValueAtTime(pRoot * ratio, t);
        pOsc.connect(padG);
        pOsc.start(t);
        pOsc.stop(t + barDur + 0.02);
      }
    }

    // 6. Expressive Detuned Supersaw Lead + 300ms Stereo Echo from Tier 1+
    const rawLead = tr.lead[step];
    if (tier >= 1 && rawLead > 0) {
      const lf = rawLead * keyMult;
      const lOsc1 = ctx.createOscillator();
      const lOsc2 = ctx.createOscillator();
      lOsc1.type = 'sawtooth';
      lOsc2.type = 'sawtooth';
      lOsc1.frequency.setValueAtTime(lf, t);
      lOsc2.frequency.setValueAtTime(lf * 1.005, t);

      const lFilter = ctx.createBiquadFilter();
      lFilter.type = 'lowpass';
      lFilter.frequency.setValueAtTime(1400 + tier * 550, t);

      const lGain = ctx.createGain();
      const amp = tier === 1 ? 0.065 : 0.09;
      lGain.gain.setValueAtTime(amp, t);
      lGain.gain.linearRampToValueAtTime(amp * 0.45, t + dur);
      lGain.gain.exponentialRampToValueAtTime(0.001, t + dur * 1.25);

      lOsc1.connect(lFilter);
      lOsc2.connect(lFilter);
      lFilter.connect(lGain);
      lGain.connect(this.leadBus);

      lOsc1.start(t);
      lOsc2.start(t);
      lOsc1.stop(t + dur * 1.3);
      lOsc2.stop(t + dur * 1.3);
    }
  }

  _playLayer(freqStart, freqEnd, duration, wave = 'triangle', gain = 0.22, harmRatio = 0.0) {
    if (this.muted) return;
    const ctx = this._ensureCtx();
    if (!ctx) return;

    const t = ctx.currentTime;
    const masterOut = this.masterGain || ctx.destination;
    const env = ctx.createGain();
    env.gain.setValueAtTime(gain, t);
    env.gain.exponentialRampToValueAtTime(Math.max(0.001, gain * 0.25), t + duration * 0.55);
    env.gain.exponentialRampToValueAtTime(0.001, t + duration);
    env.connect(masterOut);

    if (wave === 'noise') {
      const src = ctx.createBufferSource();
      src.buffer = this.noiseBuffer;
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.Q.setValueAtTime(1.2, t);
      filter.frequency.setValueAtTime(Math.max(40, freqStart), t);
      filter.frequency.exponentialRampToValueAtTime(Math.max(40, freqEnd), t + duration);
      src.connect(filter);
      filter.connect(env);
      src.start(t);
      src.stop(t + duration + 0.01);
      return;
    }

    const osc = ctx.createOscillator();
    osc.type = wave === 'saw' ? 'sawtooth' : wave;
    osc.frequency.setValueAtTime(Math.max(20, freqStart), t);
    osc.frequency.exponentialRampToValueAtTime(Math.max(20, freqEnd), t + duration);

    if (harmRatio > 0) {
      const primG = ctx.createGain();
      primG.gain.setValueAtTime(0.65, t);
      osc.connect(primG);
      primG.connect(env);

      const harmOsc = ctx.createOscillator();
      harmOsc.type = 'sine';
      harmOsc.frequency.setValueAtTime(Math.max(20, freqStart * harmRatio), t);
      harmOsc.frequency.exponentialRampToValueAtTime(Math.max(20, freqEnd * harmRatio), t + duration);
      const harmG = ctx.createGain();
      harmG.gain.setValueAtTime(0.35, t);
      harmOsc.connect(harmG);
      harmG.connect(env);

      harmOsc.start(t);
      harmOsc.stop(t + duration + 0.01);
    } else {
      osc.connect(env);
    }

    osc.start(t);
    osc.stop(t + duration + 0.01);
  }

  jump() {
    this._playLayer(280, 620, 0.10, 'triangle', 0.22, 2.0);
  }

  doubleJump() {
    this._playLayer(440, 920, 0.12, 'sine', 0.21, 1.5);
  }

  boost() {
    this._playLayer(320, 1180, 0.18, 'saw', 0.19, 1.5);
  }

  slash() {
    this._playLayer(1450, 420, 0.09, 'noise', 0.24);
    this._playLayer(1980, 1120, 0.11, 'sine', 0.16, 2.7);
  }

  kill() {
    this._playLayer(140, 55, 0.12, 'saw', 0.20);
    this._playLayer(660, 1320, 0.14, 'triangle', 0.18, 1.5);
  }

  deflect() {
    this._playLayer(1280, 2150, 0.11, 'sine', 0.22, 2.5);
  }

  shoot() {
    this._playLayer(480, 110, 0.09, 'saw', 0.15);
    this._playLayer(900, 200, 0.05, 'noise', 0.11);
  }

  death() {
    this._playLayer(240, 42, 0.28, 'saw', 0.26, 0.5);
    this._playLayer(600, 80, 0.22, 'noise', 0.18);
  }

  win() {
    [587.33, 659.25, 783.99, 880, 1174.66].forEach((freq, i) => {
      setTimeout(() => this._playLayer(freq, freq * 1.01, 0.22, 'triangle', 0.22, 2.0), i * 80);
    });
  }
}

window.KageSfx = new SoundEngine();
