use "buffered"
use "collections"
use "random"

class val SampleRate
  let _sr: F64

  new val create(sr: F64) =>
    _sr = sr

  fun f64(): F64 =>
    _sr

  fun usize(): USize =>
    _sr.usize()

  fun samples_from_seconds(sec: F64): USize =>
    (sec * _sr).usize()

interface Signal
  fun ref next()
  fun apply(): F64

class Const
  let _value: F64

  new create(value: F64) =>
    _value = value

  fun apply(): F64 =>
    _value

  fun ref next() =>
    None

class Line
  let _first: F64
  let _last: F64
  let _step: F64
  var _samples_remaining: USize
  var _acc: F64

  new create(first: F64, last: F64, samples: USize) =>
    _first = first
    _last = last

    _samples_remaining = samples
    _step = (last - first) / _samples_remaining.f64()
    _acc = _first

  fun ref next() =>
    if _samples_remaining > 0 then
      _acc = _acc + _step
      _samples_remaining = _samples_remaining - 1
    end

  fun apply(): F64 =>
    _acc

class SineGen
  let _freq: Signal
  let _sample_rate: F64
  var _value: F64

  var _step: F64
  var _acc: F64

  new create(freq: Signal, sample_rate: F64, value: F64 = 0) =>
    _freq = freq
    _sample_rate = sample_rate
    _value = value

    _step = _calc_step(_freq(), _sample_rate)
    _acc = 0

  fun tag _calc_step(freq: F64, sample_rate: F64): F64 =>
    Pi(2) / (sample_rate / freq)

  fun apply(): F64 =>
    _value

  fun ref next() =>
    _step = _calc_step(_freq(), _sample_rate)
    _acc = _acc + _step
    _value = _acc.sin()

class Add
  let _s1: Signal
  let _s2: Signal
  new create(s1: Signal, s2: Signal) =>
    _s1 = s1
    _s2 = s2

  fun ref next() =>
    None

  fun apply(): F64 =>
    _s1() + _s2()

class Mult
  let _s1: Signal
  let _s2: Signal
  new create(s1: Signal, s2: Signal) =>
    _s1 = s1
    _s2 = s2

  fun ref next() =>
    None

  fun apply(): F64 =>
    _s1() * _s2()

class FM
  let _carrier: SineGen
  let _mod: SineGen
  let _mod_times_index: Signal
  let _freq: Signal
  let _carrier_freq: Signal
  let _mod_freq: Signal
  let _index: Signal

  new create(carrier_freq: Signal, mod_freq: Signal, index: Signal, samples: USize, sample_rate: SampleRate) =>
    _carrier_freq = carrier_freq
    _mod_freq = mod_freq
    _mod = SineGen(_mod_freq, sample_rate.f64())
    _index = index
    _mod_times_index = Mult(_mod, _index)
    _freq = Add(_carrier_freq, _mod_times_index)
    _carrier = SineGen(_freq, sample_rate.f64())

  fun apply(): F64 =>
    _carrier()

  fun ref next() =>
    _mod_freq.next()
    _mod.next()
    _carrier_freq.next()
    _index.next()
    _carrier.next()

class Synth01
  let _fm: FM

  new create(carrier_freq: F64, mod_freq: F64, index: F64, samples: USize, sample_rate: SampleRate) =>
    _fm = FM(Const(carrier_freq), Const(mod_freq), Const(index), samples, sample_rate)

  fun ref next() =>
    _fm.next()

  fun apply(): F64 =>
    _fm()

primitive PlayFor
  fun apply(signal: Signal, num_samples: USize): Array[F64] =>
    let samples = Array[F64](num_samples)

    for _ in Range(0, num_samples) do
      samples.push(signal())
      signal.next()
    end

    samples

actor Main
  new create(env: Env) =>
    let sample_rate = SampleRate(44100)
    let total_frames = sample_rate.samples_from_seconds(5)

    let l_track = Track
    let r_track = Track

    let rand = Rand

    let base_note: F64 = 100
    let base_log = base_note.log2()
    let two: F64 = 2
    let note_step: F64 = 1 / 12

    for i in Range(0, total_frames, sample_rate.samples_from_seconds(0.5)) do
      let note = two.pow(base_note.log2() + (note_step * rand.int(12).f64()))
      let dur: F64 = 0.5
      let fm = Synth01(note, 60, 20, sample_rate.samples_from_seconds(dur), sample_rate)

      let s_fm = PlayFor(fm, sample_rate.samples_from_seconds(dur))

      let se_fm = QuasiGausianEnvelope(s_fm, 500, 500)
      l_track.add_samples(i + 400, se_fm, 0.4)
      r_track.add_samples(i + 400, se_fm, 0.4)

    end

    l_track.add_samples(total_frames + 1000, [0])
    r_track.add_samples(total_frames + 100, [0])

    // write to file

    let writer: Writer ref = Writer

    WriteTracks.as_stereo_32_bit_aiff(sample_rate.usize(),
      l_track,
      r_track,
      writer)

    env.out.writev(writer.done())

primitive Pi
  fun apply(n: F64 = 1, d: F64 = 1): F64 =>
    (3.14159 * n) / d
