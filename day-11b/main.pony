use "buffered"
use "collections"
use "random"

class SineGen
  let _freq: F64
  let _sample_rate: F64
  var _value: F64

  let _step: F64
  var _acc: F64

  new create(freq: F64, sample_rate: F64, value: F64 = 0) =>
    _freq = freq
    _sample_rate = sample_rate
    _value = value

    _step = Pi(2) / (_sample_rate / _freq)
    _acc = 0

  fun apply(): F64 =>
    _value

  fun ref next() =>
    _acc = _acc + _step
    _value = _acc.sin()

actor Main
  new create(env: Env) =>
    let sample_rate: USize = 44100
    let total_frames = sample_rate * 5

    let l_track = Track
    let r_track = Track

    let rand = Rand

    let base_note: F64 = 200
    let base_log = base_note.log2()
    let one: F64 = 1
    let two: F64 = 2
    let note_step: F64 = 1 / 12

    for i in Range(0, total_frames, (sample_rate) / 2) do
      let sg_beep = SineGen(1000, sample_rate.f64())
      let s_beep = Array[F64]

      for _ in Range(0, 1000) do
        s_beep.push(sg_beep())
        sg_beep.next()
      end

      let se_beep = QuasiGausianEnvelope(s_beep, 200, 200)
      l_track.add_samples(i, se_beep, 0.3)

      let note = two.pow(base_note.log2() + (note_step * rand.int(12).f64()))
      let sg_woo = SineGen(note, sample_rate.f64())
      env.err.print("note = " + note.string())
      let s_woo = Array[F64]

      for _ in Range(0, 4000) do
        s_woo.push(sg_woo())
        sg_woo.next()
      end

      let se_woo = QuasiGausianEnvelope(s_woo, 500, 500)
      r_track.add_samples(i + 400, se_woo, 0.4)

    end

    l_track.add_samples(total_frames - 1, [0])
    r_track.add_samples(total_frames - 1, [0])

    // write to file

    let writer: Writer ref = Writer

    WriteTracks.as_stereo_32_bit_aiff(sample_rate,
      l_track,
      r_track,
      writer)

    env.out.writev(writer.done())

primitive Pi
  fun apply(n: F64 = 1, d: F64 = 1): F64 =>
    (3.14159 * n) / d
