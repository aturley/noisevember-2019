use "buffered"
use "collections"
use "random"

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100
    let total_frames = frames_per_second * 5

    let normalized_track = Track

    let rand = Rand

    let stg = SineTrainGen(frames_per_second)

    let sr = frames_per_second

    let settings = Array[(USize, USize, USize)]

    let partitions: USize = 10

    for i in Range(0, partitions) do
      settings.push((200 * i, (i * total_frames) / partitions, ((i + 1) * total_frames) / partitions))
    end

    for (density, early, late) in settings.values() do
      for _ in Range(0, density) do
        let freq = RandInRange(rand, 100, 300)
        let count = RandInRange(rand, 3, 10).usize()
        let vol = RandInRange(rand, 0.1, 0.3)
        let st = stg(freq, vol, count)

        let pos = RandInRange(rand, early.f64(), late.f64()).usize()

        normalized_track.add_samples(pos, st)
      end
    end

    normalized_track.add_samples(total_frames - 1, [0])

    // write to file

    let writer: Writer ref = Writer

    WriteTracks.as_stereo_32_bit_aiff(frames_per_second,
      normalized_track,
      normalized_track,
      writer)

    env.out.writev(writer.done())

class Track
  let _samples: Array[F64]

  new create(alloc: USize = 2000) =>
    _samples = Array[F64](alloc)

  fun ref add_samples(pos: USize, new_samples: Array[F64]) =>
    let needed_space = pos + new_samples.size()

    if _samples.space() < needed_space then
      _samples.reserve(needed_space)
    end

    if _samples.size() < pos then
      for _ in Range(_samples.size(), pos) do
        _samples.push(0)
      end
    end

    for (i, s) in new_samples.pairs() do
      try
        _samples(pos + i)? = _samples(pos + i)? + s
      else
        _samples.push(s)
      end
    end

  fun samples(): this->Array[F64] =>
    _samples

class SineTrainGen
  let _sample_rate: USize

  new create(sample_rate: USize) =>
    _sample_rate = sample_rate

  fun apply(freq: F64, scale: F64, num: USize): Array[F64] =>
    let num_samples = ((_sample_rate.f64() / freq) * num.f64()).usize()
    let samples = Array[F64](num_samples)

    for a in Range[F64](0, Pi(2) * num.f64(), Pi(2) / (_sample_rate.f64() / freq)) do
      samples.push(a.sin() * scale)
    end

    samples

primitive Pi
  fun apply(n: F64 = 1, d: F64 = 1): F64 =>
    (3.14159 * n) / d

primitive RandInRange
  fun apply(rand: Random, min: F64, max: F64): F64 =>
    let d = max - min

    min + (d * rand.real())
