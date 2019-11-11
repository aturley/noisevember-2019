use "buffered"
use "collections"
use "random"

primitive QuasiGausianEnvelope
  fun apply(input: Array[F64], attack_length: USize, decay_length: USize): Array[F64] =>
    (let al, let dl) = if input.size() >= (attack_length + decay_length) then
      (attack_length, decay_length)
    else
      let ad_ratio = attack_length.f64() / (attack_length + decay_length).f64()
      ((input.size().f64() * ad_ratio).usize() - 1, (input.size().f64() * (1 - ad_ratio)).usize() - 1)
    end

    let out = Array[F64](input.size())

    let input_it = input.values()

    let sustain_length = input.size() - (al + dl)

    for a in Range[F64](0, Pi(), Pi() / al.f64()) do
      let factor = (1 - a.cos()) / 2
      try
        out.push(input_it.next()? * factor)
      end
    end

    for _ in Range(0, sustain_length) do
      try
        out.push(input_it.next()?)
      end
    end

    for a in Range[F64](Pi(), Pi(2), Pi() / dl.f64()) do
      let factor = (1 - a.cos()) / 2
      try
        out.push(input_it.next()? * factor)
      end
    end

    out

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100
    let total_frames = frames_per_second * 5

    let l_track = Track
    let r_track = Track

    let rand = Rand

    let stg = SineTrainGen(frames_per_second)

    let sr = frames_per_second

    let settings = Array[(USize, USize, USize)]

    let partitions: USize = 10

    for i in Range(0, partitions) do
      settings.push((20 * i, (i * total_frames) / partitions, ((i + 1) * total_frames) / partitions))
    end

    for (density, early, late) in settings.values() do
      for _ in Range(0, density) do
        let freq = RandInRange(rand, 100, 1000)
        let count = RandInRange(rand, 3, 10).usize()
        let vol = RandInRange(rand, 0.05, 0.1)
        let st = stg(freq, vol, count)

        let env_st = QuasiGausianEnvelope(st, 300, 300)

        let pos = RandInRange(rand, early.f64(), late.f64()).usize()

        let bal = if freq > 500 then
          if rand.real() > 0.5 then
            RandInRange(rand, 0.001, 0.1)
          else
            RandInRange(rand, 0.9, 0.999)
          end
        else
          RandInRange(rand, 0.4, 0.6)
        end

        l_track.add_samples(pos, env_st, bal)
        r_track.add_samples(pos, env_st, 1 - bal)
      end
    end

    l_track.add_samples(total_frames - 1, [0])
    r_track.add_samples(total_frames - 1, [0])

    // write to file

    let writer: Writer ref = Writer

    WriteTracks.as_stereo_32_bit_aiff(frames_per_second,
      l_track,
      r_track,
      writer)

    env.out.writev(writer.done())

class Track
  let _samples: Array[F64]

  new create(alloc: USize = 2000) =>
    _samples = Array[F64](alloc)

  fun ref add_samples(pos: USize, new_samples: Array[F64], lvl: F64 = 1) =>
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
        _samples(pos + i)? = _samples(pos + i)? + (s * lvl)
      else
        _samples.push(s * lvl)
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
