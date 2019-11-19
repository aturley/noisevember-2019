use "collections"

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
