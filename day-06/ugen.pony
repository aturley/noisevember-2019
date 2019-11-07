use "collections"
use "itertools"
use "random"

trait UGen
  fun val samples(freq: F64, sample_rate: USize): UGenIter

trait UGenIter
  fun ref next(): F64

class val Gen01 is UGen
  let _array: Array[F64] val

  new val create(size': USize, points: Array[(USize, F64)] val) =>
    let array': Array[F64] trn = recover Array[F64].init(0, size') end

    let it = points.values()

    try
      it.next()?
    end

    for (s, e) in Iter[(USize, F64)](points.values()).zip[(USize, F64)](it) do
      let dy = (e._2 - s._2) / (e._1 - s._1).f64()
      var acc: F64 = 0
      for x in Range(s._1, e._1) do
        try
          array'(x)? = s._2 + acc
        end
        acc = acc + dy
      end
    end

    _array = consume array'

  fun val apply(i: USize): F64 =>
    try
      _array(i % _array.size())?
    else
      0
    end

  fun val samples(freq: F64, sample_rate: USize): Gen01Iter =>
    let stride = (_array.size().f64() * freq) / sample_rate.f64()
    Gen01Iter(this, sample_rate, freq)

  fun size(): USize =>
    _array.size()

  fun string(): String =>
    let s: String trn = recover String end
    for (x, y) in _array.pairs() do
      s.append("(" + x.string() + "," + y.string() + ")\n")
    end

    consume s

class Gen01Iter is UGenIter
  var _acc: F64 = 0
  let _gen: Gen01
  let _sample_rate: USize
  var _stride: F64

  new create(gen: Gen01, sample_rate: USize, freq: F64) =>
    _gen = gen
    _sample_rate = sample_rate
    _stride = calc_stride(gen, freq, sample_rate)

  new from_stride(gen: Gen01, sample_rate: USize, stride: F64) =>
    _gen = gen
    _sample_rate = sample_rate
    _stride = stride

  fun tag calc_stride(gen: Gen01, freq: F64, sample_rate: USize): F64 =>
    (gen.size().f64() * freq) / sample_rate.f64()

  fun ref set_freq(freq: F64) =>
    _stride = calc_stride(_gen, freq, _sample_rate)

  fun ref next(): F64 =>
    let o = _gen(_acc.usize())
    _acc = _acc + _stride
    o

class val Const is UGen
  let _v: F64

  new val create(v: F64) =>
    _v = v

  fun val samples(freq: F64, sample_rate: USize): UGenIter =>
    ConstIter(_v)

class ConstIter is UGenIter
  let _v: F64

  new create(v: F64) =>
    _v = v

  fun ref next(): F64 =>
    _v
