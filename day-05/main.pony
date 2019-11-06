use "buffered"
use "collections"
use "itertools"
use "random"

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100
    let freq: F64 = 440
    let total_frames = frames_per_second * 2

    let sound = Stereo32BitSoundDataChunk

    let gen_wave = Gen01(512, [as (USize, F64):
      (0, 0)
      (50, 0.999)
      (205, 0.999)
      (306, -0.999)
      (461, -0.999)
      (512, 0)])

    let gen_mod = Gen01(512, [as (USize, F64):
      (0, 0)
      (256, 50)
      (512, 0)])

    let g_w = gen_wave.samples(freq, frames_per_second)

    let rand = Rand

    let noise = Noise(rand, 40)

    for _ in Range(0, total_frames / 2) do
      // let sample = (g_w.next(freq) * I32.max_value().f64()).i32()
      let nn = noise.next()
      let sample = (g_w.next(freq) * nn * I32.max_value().f64()).i32()
      sound.add_frame([sample; sample])
    end

    for _ in Range(0, total_frames / 2) do
      // let sample = (g_w.next(freq * 2) * I32.max_value().f64()).i32()
      let nn = noise.next()
      let sample = (g_w.next(freq * 2) * nn * I32.max_value().f64()).i32()
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
  var _next: F64
  var _delta: F64

  new create(rand: Rand, steps: USize) =>
    _rand = rand
    _steps = steps
    _curr = 0
    _next = make_next(rand)
    _delta = make_delta(_curr, _next, steps)

  fun tag make_next(rand: Random): F64 =>
    (rand.real() * 2) - 1

  fun tag make_delta(a: F64, b: F64, steps: USize): F64 =>
    (b - a) / steps.f64()

  fun ref next(steps: USize = 0): F64 =>
    if (steps != 0) and (steps != _steps) then
      _steps = steps
      _delta = make_delta(_curr, _next, _steps)
    end

    let o = _curr

    if (_next - _curr).abs() > _delta.abs() then
      _curr = _curr + _delta
      o
    else
      _curr = _next
      _next = make_next(_rand)
      _delta = make_delta(_curr, _next, _steps)

      o
    end
