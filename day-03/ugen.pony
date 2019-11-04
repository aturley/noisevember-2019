use "collections"
use "itertools"

class val Gen01
  let _array: Array[F64] val

  new val create(size: USize, points: Array[(USize, F64)] val) =>
    let array': Array[F64] trn = recover Array[F64].init(0, size) end

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

  fun val samples(freq: F64, sample_rate: USize): Iterator[F64] =>
    let stride = ((_array.size().f64() * freq) / sample_rate.f64()).usize()
    Gen01Iter(this, stride)

  fun string(): String =>
    let s: String trn = recover String end
    for (x, y) in _array.pairs() do
      s.append("(" + x.string() + "," + y.string() + ")\n")
    end

    consume s

class Gen01Iter
  var _acc: USize = 0
  let _gen: Gen01
  let _stride: USize

  new create(gen: Gen01, stride: USize) =>
    _gen = gen
    _stride = stride

  fun ref has_next(): Bool =>
    true

  fun ref next(): F64 =>
    let o = _gen(_acc)
    _acc = _acc + _stride
    o
