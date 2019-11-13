use "collections"

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
