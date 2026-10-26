extends RefCounted
## Stage 30: deterministic recent-motion estimation and exponential integration.
## Coordinates may be ground displacement or log(camera distance).


static func begin(samples: Array, time: float) -> void:
	samples.clear()
	samples.append({"time": time, "position": Vector2.ZERO})


static func record(samples: Array, displacement: Vector2, time: float, window: float) -> void:
	if samples.is_empty():
		begin(samples, time - 1.0 / 120.0)
	var last: Dictionary = samples.back()
	# Several input events may arrive in one frame. Aggregate them rather than
	# inventing a separate frame duration for each event.
	if is_equal_approx(float(last["time"]), time) and absf(float(last["time"]) - time) < 0.000001:
		if samples.size() == 1:
			last["time"] = time - 1.0 / 120.0
			samples.append({"time": time, "position": displacement})
		else:
			last["position"] += displacement
	else:
		samples.append({"time": time, "position": last["position"] + displacement})
	var cutoff := time - window
	# Keep one point before the cutoff to interpolate a partial segment.
	while samples.size() > 2 and float(samples[1]["time"]) <= cutoff:
		samples.pop_front()


static func release_velocity(samples: Array, time: float, window: float) -> Vector2:
	if samples.size() < 2:
		return Vector2.ZERO
	var latest: Dictionary = samples.back()
	var cutoff := time - maxf(window, 0.001)
	if float(latest["time"]) <= cutoff:
		return Vector2.ZERO
	var start := maxf(cutoff, float(samples[0]["time"]))
	var position: Vector2 = samples[0]["position"]
	for i in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		if float(b["time"]) >= start:
			var k := clampf((start - float(a["time"])) / maxf(float(b["time"]) - float(a["time"]), 0.000001), 0, 1)
			position = (a["position"] as Vector2).lerp(b["position"], k)
			break
	return (latest["position"] - position) / maxf(time - start, 0.001)


static func decay_distance(speed: float, friction: float, delta: float) -> float:
	# Exact integral: a 30/60/120 Hz device travels the same distance.
	var rate := maxf(friction, 0.001)
	return speed * (1.0 - exp(-rate * maxf(delta, 0))) / rate
