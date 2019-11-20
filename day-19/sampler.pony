use "collections"

class Sampler
  let _samples: Array[F64]

  new create(samples: Array[F64]) =>
    _samples = samples

  fun raw(i: USize): F64 ? =>
    _samples(i)?

  fun apply(start_n: F64, end_n: F64, num_samples: USize): Array[F64] =>
    let samples = Array[F64](num_samples)

    let step = (end_n - start_n) / (num_samples.f64() - 1)

    for n in Range[F64](start_n, end_n + (step / 10), step) do
      samples.push(try norm_lerp(n)? else 0 end)
    end

    samples

  fun norm_lerp(n: F64): F64 ? =>
    let prev = norm_to_pos(n)?
    let next = prev + 1
    let prev_s = _samples(prev)?
    let next_s = _samples(next)?
    let dist = 1 / (_samples.size() - 1).f64()
    let rise = next_s - prev_s

    let fraction = (n - pos_to_norm(prev)?) / dist

    let sample = prev_s + ((next_s - prev_s) * fraction)

    sample

  fun norm_to_pos(n: F64): USize ? =>
    if (n < 0) or (n > 1) then
      error
    end

    ((_samples.size() - 1).f64() * n).usize()

  fun pos_to_norm(p: USize): F64 ? =>
    if p >= _samples.size() then
      error
    end

    (p.f64() / (_samples.size() - 1).f64())

  fun size(): USize =>
    _samples.size()
