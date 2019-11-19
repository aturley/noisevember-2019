use "random"

primitive RandInRange
  fun apply(rand: Random, min: F64, max: F64): F64 =>
    let d = max - min

    min + (d * rand.real())
