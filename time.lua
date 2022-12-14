--[=[

	Wall clock, monotonic clock, and sleep function (Windows, Linux and OSX).
	Written by Cosmin Apreutesei. Public Domain.

	now() -> ts          current time with ~100us precision
	clock() -> ts        monotonic clock in seconds with ~1us precision
	startclock           clock() when this module was loaded
	sleep(s)             sleep with sub-second precision (~10-100ms)

	now() -> ts

		Reads the time as a UNIX timestamp (a Lua number).
		It is the same as the time returned by `os.time()` on all platforms,
		except it has sub-second precision. It is affected by drifting,
		leap seconds and time adjustments by the user. It is not affected
		by timezones. It can be used to synchronize time between different
		boxes on a network regardless of platform.

	clock() -> ts

		Reads a monotonic performance counter, and is thus more accurate than
		`now()`, it should never go back or drift, but it doesn't have
		a fixed time base between program executions. It can be used
		for measuring short time intervals for thread synchronization, etc.

	sleep(s)

		Suspends the current process `s` seconds. Different than wait() which
		only suspends the current Lua thread.

]=]

local ffi = require'ffi'
local C = ffi.C

if ffi.os == 'Windows' then

	ffi.cdef[[
	void time_GetSystemTimeAsFileTime(uint64_t*) asm("GetSystemTimeAsFileTime");
	int  time_QueryPerformanceCounter(int64_t*) asm("QueryPerformanceCounter");
	int  time_QueryPerformanceFrequency(int64_t*) asm("QueryPerformanceFrequency");
	void time_Sleep(uint32_t ms) asm("Sleep");
	]]

	local t = ffi.new'uint64_t[1]'
	local DELTA_EPOCH_IN_100NS = 116444736000000000ULL

	function os.now()
		C.time_GetSystemTimeAsFileTime(t)
		return tonumber(t[0] - DELTA_EPOCH_IN_100NS) * 1e-7
	end

	assert(C.time_QueryPerformanceFrequency(t) ~= 0)
	local inv_qpf = 1 / tonumber(t[0]) --precision loss in e-10

	local t0 = 0
	function clock()
		assert(C.time_QueryPerformanceCounter(t) ~= 0)
		return tonumber(t[0]) * inv_qpf - t0
	end
	t0 = clock()
	startclock = t0

	function os.sleep(s)
		C.time_Sleep(s * 1000)
	end

elseif ffi.os == 'Linux' or ffi.os == 'OSX' then

	ffi.cdef[[
	typedef struct {
		long s;
		long ns;
	} time_timespec;

	int time_nanosleep(time_timespec*, time_timespec *) asm("nanosleep");
	]]

	local EINTR = 4

	local t = ffi.new'time_timespec'

	function os.sleep(s)
		local int, frac = math.modf(s)
		t.s = int
		t.ns = frac * 1e9
		local ret = C.time_nanosleep(t, t)
		while ret == -1 and ffi.errno() == EINTR do --interrupted
			ret = C.time_nanosleep(t, t)
		end
		assert(ret == 0)
	end

	if ffi.os == 'Linux' then

		ffi.cdef[[
		int time_clock_gettime(int clock_id, time_timespec *tp) asm("clock_gettime");
		]]

		local CLOCK_REALTIME = 0
		local CLOCK_MONOTONIC = 1

		local ok, rt_C = pcall(ffi.load, 'rt')
		local clock_gettime = (ok and rt_C or C).time_clock_gettime

		local function tos(t)
			return tonumber(t.s) + tonumber(t.ns) / 1e9
		end

		function os.now()
			assert(clock_gettime(CLOCK_REALTIME, t) == 0)
			return tos(t)
		end

		local t0 = 0
		function clock()
			assert(clock_gettime(CLOCK_MONOTONIC, t) == 0)
			return tos(t) - t0
		end
		t0 = clock()
		startclock = t0

	elseif ffi.os == 'OSX' then

		ffi.cdef[[
		typedef struct {
			long    s;
			int32_t us;
		} time_timeval;

		typedef struct {
			uint32_t numer;
			uint32_t denom;
		} time_mach_timebase_info_data_t;

		int      time_gettimeofday(time_timeval*, void*) asm("gettimeofday");
		int      time_mach_timebase_info(time_mach_timebase_info_data_t* info) asm("mach_timebase_info");
		uint64_t time_mach_absolute_time(void) asm("mach_absolute_time");
		]]

		local t = ffi.new'time_timeval'

		function os.now()
			assert(C.time_gettimeofday(t, nil) == 0)
			return tonumber(t.s) + tonumber(t.us) * 1e-6
		end

		--NOTE: this appears to be pointless on Intel Macs. The timebase fraction
		--is always 1/1 and mach_absolute_time() does dynamic scaling internally.
		local timebase = ffi.new'time_mach_timebase_info_data_t'
		assert(C.time_mach_timebase_info(timebase) == 0)
		local scale = tonumber(timebase.numer) / tonumber(timebase.denom) / 1e9
		local t0
		function clock()
			return tonumber(C.time_mach_absolute_time()) * scale - t0
		end
		t0 = clock()

	end --OSX

end --Linux or OSX
