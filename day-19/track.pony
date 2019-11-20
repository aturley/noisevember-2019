use "collections"

class Track
  let _samples: Array[F64]

  new create(alloc: USize = 2000) =>
    _samples = Array[F64](alloc)

  fun ref add_samples(pos: USize, new_samples: Array[F64], lvl: F64 = 1): USize =>
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

    pos + new_samples.size()

  fun samples(): this->Array[F64] =>
    _samples
