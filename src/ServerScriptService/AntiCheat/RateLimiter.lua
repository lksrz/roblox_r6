local RateLimiter = {}
local buckets = {} -- [userId][key] = {count, t0}

function RateLimiter.Allow(player, key, perMinute)
    local now = os.clock()
    local u = player.UserId
    buckets[u] = buckets[u] or {}
    local b = buckets[u][key]
    if not b or now - b.t0 > 60 then b = {count=0, t0=now}; buckets[u][key]=b end
    if b.count >= perMinute then return false end
    b.count += 1
    return true
end

return RateLimiter

