use "buffered"
use "collections"
use "itertools"
use "random"

class MyInstrument
  let _waveform: Gen01Iter
  let _freq: Gen01Iter
  let _noise: Noise
  let _noise_mod: Gen01Iter
  let _env: Gen01Iter

  new create(waveform: Gen01Iter, freq: Gen01Iter,
    noise: Noise, noise_mod: Gen01Iter,
    env: Gen01Iter)
  =>
    _waveform = waveform
    _freq = freq
    _noise = noise
    _noise_mod = noise_mod
    _env = env

  fun ref next(): F64 =>
    _waveform.set_freq(_freq.next())
    _noise.set_steps(_noise_mod.next().usize())
    _waveform.next() * _noise.next() * _env.next()

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100
    let freq: F64 = 440
    let total_frames = frames_per_second * 5

    let sound = Stereo32BitSoundDataChunk

    let rand = Rand

    let gen_wave = Gen01(512, [as (USize, F64):
      (0, 0)
      (50, 0.999)
      (205, 0.999)
      (306, -0.999)
      (461, -0.999)
      (512, 0)])

    let wave_mod = Gen01(512, [as (USize, F64):
      (0, 0)
      (256, 100)
      (512, 0)])

    let g_w = gen_wave.samples(freq, frames_per_second)

    let w_m = wave_mod.samples(1, frames_per_second)

    let noise = Noise(rand, 40)

    let noise_mod = Gen01(512, [as (USize, F64):
      (0, 40)
      (128, 80)
      (256, 60)
      (512, 40)])

    let n_m = wave_mod.samples(1, frames_per_second)

    let envelope = Gen01(512, [as (USize, F64):
      (0, 0)
      (20, 0.999)
      (470, 0.999)
      (512, 0)])

    let e = envelope.samples(0.5, frames_per_second)

    let my_inst = MyInstrument(g_w, w_m, noise, n_m, e)

    for _ in Range(0, total_frames) do
      let sample = (my_inst.next() * I32.max_value().f64()).i32()
      sound.add_frame([sample; sample])
    end

    let common_chunk = CommonChunk(2, sound.num_frames().u32(), 32, frames_per_second.f64())

    let form = FormAIFFChunk

    form .> add_chunk(common_chunk) .> add_chunk(sound)

    let writer: Writer ref = Writer

    form.write(writer)

    env.out.writev(writer.done())

primitive Pi
  fun apply(n: F64 = 1 , d: F64 = 1): F64 =>
    (3.1415926535 * n) / d

class Noise
  let _rand: Random
  var _steps: USize
  var _curr: F64
  var _steps_taken: USize
  var _next: F64
  var _delta: F64

  new create(rand: Rand, steps: USize) =>
    _rand = rand
    _steps = steps
    _curr = 0
    _steps_taken = 0
    _next = make_next(rand)
    _delta = make_delta(_curr, _next, steps)

  fun tag make_next(rand: Random): F64 =>
    (rand.real() * 2) - 1

  fun tag make_delta(a: F64, b: F64, steps: USize): F64 =>
    (b - a) / steps.f64()

  fun ref set_steps(steps: USize) =>
    if (steps != 0) and (steps != _steps) then
      _steps = steps
      let dist_from_start = (_steps_taken.f64() * _delta)
      let start = _curr - dist_from_start
      _delta = make_delta(start, _next, _steps)
      _steps_taken = (dist_from_start / _delta).usize()
    end

  fun ref next(): F64 =>
    let o = _curr

    if _steps_taken < _steps then
      _steps_taken = _steps_taken + 1
      _curr = _curr + _delta
      o
    else
      _steps_taken = 0
      _curr = _next
      _next = make_next(_rand)
      _delta = make_delta(_curr, _next, _steps)

      o
    end
