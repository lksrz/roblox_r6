-- Construction.Generator: Procedural building generator (rooms, corridors, walls, doors, windows)
-- Single-responsibility: generate a building Model from config
-- No network, no input; pure generation using axis-aligned rectangles and part emission

local Workspace = game:GetService("Workspace")

local Generator = {}

export type Rect = { x0: number, z0: number, x1: number, z1: number }
export type Edge = { axis: "x" | "z", pos: number, s: number, e: number }

local function rectWidth(r: Rect) return math.abs(r.x1 - r.x0) end
local function rectLength(r: Rect) return math.abs(r.z1 - r.z0) end
local function rectCenter(r: Rect) return (r.x0 + r.x1) * 0.5, (r.z0 + r.z1) * 0.5 end
local function rectClone(r: Rect): Rect return { x0 = r.x0, z0 = r.z0, x1 = r.x1, z1 = r.z1 } end
local function makeRect(x0, z0, x1, z1): Rect return { x0 = x0, z0 = z0, x1 = x1, z1 = z1 } end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Build BSP of footprint to rooms. Along splits we add corridor rects that connect children.
local function bspPartition(rng: Random, rect: Rect, cfg)
    local nodes = {}
    local corridors: { Rect } = {}

    local minW = cfg.Room.MinSize.Width
    local minL = cfg.Room.MinSize.Length
    local maxW = cfg.Room.MaxSize.Width
    local maxL = cfg.Room.MaxSize.Length
    local cw = cfg.CorridorWidth

    local function splitRec(r: Rect, depth: number)
        local w, l = rectWidth(r), rectLength(r)
        local canSplitW = w > maxW
        local canSplitL = l > maxL
        if (not canSplitW and not canSplitL) or depth > 50 then
            table.insert(nodes, r)
            return
        end

        local splitAlongX
        if canSplitW and canSplitL then
            splitAlongX = (w > l) -- bias towards the longer axis
        else
            splitAlongX = canSplitW
        end

        if splitAlongX then
            -- split along X: vertical cut parallel to Z, at x = k
            local minK = r.x0 + minW
            local maxK = r.x1 - minW
            if maxK - minK < minW then
                -- cannot split safely, accept as leaf
                table.insert(nodes, r)
                return
            end
            local k = rng:NextNumber(minK, maxK)
            -- clamp to avoid super small rooms
            k = clamp(k, r.x0 + minW, r.x1 - minW)
            local left = makeRect(r.x0, r.z0, k, r.z1)
            local right = makeRect(k, r.z0, r.x1, r.z1)

            -- add two corridor bands hugging the split so both adjacent rooms share an edge at x=k
            local leftBand = makeRect(k - cw * 0.5, r.z0, k, r.z1)
            local rightBand = makeRect(k, r.z0, k + cw * 0.5, r.z1)
            table.insert(corridors, leftBand)
            table.insert(corridors, rightBand)

            splitRec(left, depth + 1)
            splitRec(right, depth + 1)
        else
            -- split along Z: horizontal cut parallel to X, at z = k
            local minK = r.z0 + minL
            local maxK = r.z1 - minL
            if maxK - minK < minL then
                table.insert(nodes, r)
                return
            end
            local k = rng:NextNumber(minK, maxK)
            k = clamp(k, r.z0 + minL, r.z1 - minL)
            local bottom = makeRect(r.x0, r.z0, r.x1, k)
            local top = makeRect(r.x0, k, r.x1, r.z1)

            -- add two corridor bands hugging the split so both adjacent rooms share an edge at z=k
            local lowerBand = makeRect(r.x0, k - cw * 0.5, r.x1, k)
            local upperBand = makeRect(r.x0, k, r.x1, k + cw * 0.5)
            table.insert(corridors, lowerBand)
            table.insert(corridors, upperBand)

            splitRec(bottom, depth + 1)
            splitRec(top, depth + 1)
        end
    end

    splitRec(rect, 0)
    return nodes, corridors
end

-- Utilities to detect shared borders between a room and corridor to place doors
local function overlap1D(a0, a1, b0, b1)
    local s = math.max(a0, b0)
    local e = math.min(a1, b1)
    return s, e, (e > s)
end

local function sharedEdge(a: Rect, b: Rect): Edge?
    -- Check if they touch along a full edge with positive overlap in the other axis
    -- Left/right edges (x constant)
    if math.abs(a.x1 - b.x0) < 1e-3 or math.abs(b.x1 - a.x0) < 1e-3 then
        local x = math.abs(a.x1 - b.x0) < 1e-3 and a.x1 or b.x1
        local s, e, ok = overlap1D(a.z0, a.z1, b.z0, b.z1)
        if ok then return { axis = "z", pos = x, s = s, e = e } end
    end
    -- Top/bottom edges (z constant)
    if math.abs(a.z1 - b.z0) < 1e-3 or math.abs(b.z1 - a.z0) < 1e-3 then
        local z = math.abs(a.z1 - b.z0) < 1e-3 and a.z1 or b.z1
        local s, e, ok = overlap1D(a.x0, a.x1, b.x0, b.x1)
        if ok then return { axis = "x", pos = z, s = s, e = e } end
    end
    return nil
end

-- Lay out door openings on edges between rooms and corridors
local function planDoors(rng: Random, rooms: {Rect}, corridors: {Rect}, cfg)
    local doors = {} :: { [string]: { center: number, width: number } }
    local width = math.max(cfg.Door.Width or 6, (cfg.Door.MinWidth or 0))
    local maxPerRoom = 1
    local function edgeKey(edge: Edge)
        local function r(v) return string.format("%.2f", v) end
        return table.concat({ edge.axis, r(edge.pos), r(edge.s), r(edge.e) }, ":")
    end

    for _, room in ipairs(rooms) do
        local candidates = {}
        for _, hall in ipairs(corridors) do
            local edge = sharedEdge(room, hall)
            if edge then table.insert(candidates, edge) end
        end
        -- Shuffle candidates
        for i = #candidates, 2, -1 do
            local j = rng:NextInteger(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local count = 0
        for _, edge in ipairs(candidates) do
            local margin = width * 0.5
            local s = edge.s + margin
            local e = edge.e - margin
            if e > s then
                local center = rng:NextNumber(s, e)
                doors[edgeKey(edge)] = { center = center, width = width }
                count = count + 1
                if count >= maxPerRoom then break end
            end
        end
        -- Fallback: guarantee at least one doorway per room
        if count == 0 and #candidates > 0 then
            -- pick the longest shared edge and place a centered door, clamped to edge length
            local best, bestLen
            for _, edge in ipairs(candidates) do
                local len = edge.e - edge.s
                if (not best) or (len > bestLen) then best, bestLen = edge, len end
            end
            if best and bestLen and bestLen > 0.5 then
                local desired = math.min(width, bestLen - 0.2)
                local center = (best.s + best.e) * 0.5
                doors[edgeKey(best)] = { center = center, width = math.max(2, desired) }
            end
        end
    end
    return doors
end

-- Select exterior doors on the outer footprint; also add short entrance corridors
local function planExteriorDoorsAndEntrances(rng: Random, footprint: Rect, corridors: {Rect}, cfg)
    local planned = {}
    local cnt = math.max(0, cfg.ExteriorDoors or 0)
    if cnt == 0 then return planned, corridors end

    local margin = cfg.Window.InsetFromCorner or 4
    local doorW = cfg.Door.Width
    local cw = cfg.CorridorWidth

    local choices = {
        { axis = "x", pos = footprint.z0, s = footprint.x0 + margin, e = footprint.x1 - margin }, -- south edge
        { axis = "x", pos = footprint.z1, s = footprint.x0 + margin, e = footprint.x1 - margin }, -- north edge
        { axis = "z", pos = footprint.x0, s = footprint.z0 + margin, e = footprint.z1 - margin }, -- west edge
        { axis = "z", pos = footprint.x1, s = footprint.z0 + margin, e = footprint.z1 - margin }, -- east edge
    }

    -- Pick edges and place doors
    for i = 1, cnt do
        local edge = choices[rng:NextInteger(1, #choices)]
        local span = edge.e - edge.s
        if span <= doorW * 1.5 then break end
        local center = rng:NextNumber(edge.s + doorW, edge.e - doorW)
        table.insert(planned, { axis = edge.axis, pos = edge.pos, center = center, width = doorW })

        -- Add entrance corridor spanning across the building …
        if edge.axis == "x" then
            -- north/south wall: primary corridor goes along Z across the footprint
            local x0 = center - cw * 0.5
            local x1 = center + cw * 0.5
            table.insert(corridors, makeRect(x0, footprint.z0, x1, footprint.z1))
            -- plus a perpendicular cross corridor across X at mid Z to guarantee intersections
            local zMid = (footprint.z0 + footprint.z1) * 0.5
            local z0 = zMid - cw * 0.5
            local z1 = zMid + cw * 0.5
            table.insert(corridors, makeRect(footprint.x0, z0, footprint.x1, z1))
        else
            -- east/west wall: primary corridor goes along X across the footprint
            local z0 = center - cw * 0.5
            local z1 = center + cw * 0.5
            table.insert(corridors, makeRect(footprint.x0, z0, footprint.x1, z1))
            -- plus a perpendicular cross corridor across Z at mid X to guarantee intersections
            local xMid = (footprint.x0 + footprint.x1) * 0.5
            local x0 = xMid - cw * 0.5
            local x1 = xMid + cw * 0.5
            table.insert(corridors, makeRect(x0, footprint.z0, x1, footprint.z1))
        end
    end

    return planned, corridors
end

-- Segment math: subtract intervals from [s,e] and return kept segments
local function subtractIntervals(s: number, e: number, openings: { {s: number, e: number} })
    table.sort(openings, function(a, b) return a.s < b.s end)
    local cursor = s
    local kept = {}
    for _, o in ipairs(openings) do
        local os = clamp(o.s, s, e)
        local oe = clamp(o.e, s, e)
        if oe > os and os > cursor then
            table.insert(kept, { s = cursor, e = os })
        end
        cursor = math.max(cursor, oe)
    end
    if cursor < e then
        table.insert(kept, { s = cursor, e = e })
    end
    return kept
end

-- Emit a set of wall parts along a straight edge with vertical bands to produce holes for doors/windows
local function emitWallBandParts(container: Instance, color: Color3, edge: Edge, bandY0: number, bandY1: number, openings, thickness: number, material: Enum.Material?)
    if bandY1 <= bandY0 then return end
    local segs = (#openings > 0) and subtractIntervals(edge.s, edge.e, openings) or { { s = edge.s, e = edge.e } }
    -- Small seam padding so adjacent segments from separate edges overlap slightly
    local seamPad = 0.2
    for _, seg in ipairs(segs) do
        local s = seg.s - seamPad
        local e = seg.e + seamPad
        local mid = (s + e) * 0.5
        local len = e - s
        if len > 0.05 then
            local part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = true
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Color = color
            if material then part.Material = material end
            local height = bandY1 - bandY0
            if edge.axis == "x" then
                part.Size = Vector3.new(len, height, thickness)
                part.CFrame = CFrame.new(mid, bandY0 + height * 0.5, edge.pos)
            else
                part.Size = Vector3.new(thickness, height, len)
                part.CFrame = CFrame.new(edge.pos, bandY0 + height * 0.5, mid)
            end
            part.Parent = container
        end
    end
end

local function computeExteriorWindows(edge: Edge, cfg)
    local arr = {}
    local spacing = cfg.Window.Spacing
    local inset = cfg.Window.InsetFromCorner
    local half = cfg.Window.Width * 0.5
    local s = edge.s + inset
    local e = edge.e - inset
    local at = s
    while at + half <= e - half do
        table.insert(arr, { s = at - half, e = at + half })
        at = at + spacing
    end
    return arr
end

local function gatherExteriorEdges(footprint: Rect)
    return {
        { axis = "x", pos = footprint.z0, s = footprint.x0, e = footprint.x1 }, -- south
        { axis = "x", pos = footprint.z1, s = footprint.x0, e = footprint.x1 }, -- north
        { axis = "z", pos = footprint.x0, s = footprint.z0, e = footprint.z1 }, -- west
        { axis = "z", pos = footprint.x1, s = footprint.z0, e = footprint.z1 }, -- east
    }
end

-- Gather all room<->corridor shared edges (interior walls) for junction analysis
local function gatherInteriorEdges(rooms: {Rect}, halls: {Rect})
    local edges: { Edge } = {}
    for _, room in ipairs(rooms) do
        for _, hall in ipairs(halls) do
            local edge = sharedEdge(room, hall)
            if edge then table.insert(edges, edge) end
        end
    end
    return edges
end

local function computeJunctionExclusionsForEdge(exteriorEdge: Edge, interiorEdges: {Edge}, footprint: Rect, clearance: number)
    local exclusions = {}
    if exteriorEdge.axis == "x" then
        -- exterior edge runs along X at z = pos; perpendicular interior edges are axis 'z'
        for _, e in ipairs(interiorEdges) do
            if e.axis == "z" then
                -- e runs from z in [s,e] at x = e.pos; check if it meets this boundary
                if (exteriorEdge.pos >= math.min(e.s, e.e) - 1e-3) and (exteriorEdge.pos <= math.max(e.s, e.e) + 1e-3) then
                    local x = e.pos
                    table.insert(exclusions, { s = x - clearance, e = x + clearance })
                end
            end
        end
    else
        -- exterior edge runs along Z at x = pos; perpendicular interior edges are axis 'x'
        for _, e in ipairs(interiorEdges) do
            if e.axis == "x" then
                if (exteriorEdge.pos >= math.min(e.s, e.e) - 1e-3) and (exteriorEdge.pos <= math.max(e.s, e.e) + 1e-3) then
                    local z = e.pos
                    table.insert(exclusions, { s = z - clearance, e = z + clearance })
                end
            end
        end
    end
    return exclusions
end

-- Corridor connectivity utilities
local function rectsOverlap(a: Rect, b: Rect, eps: number?)
    eps = eps or 1e-3
    local sX = math.max(a.x0, b.x0)
    local eX = math.min(a.x1, b.x1)
    local sZ = math.max(a.z0, b.z0)
    local eZ = math.min(a.z1, b.z1)
    return (eX - sX) > -eps and (eZ - sZ) > -eps
end

local function centerOf(r: Rect)
    return (r.x0 + r.x1) * 0.5, (r.z0 + r.z1) * 0.5
end

-- Ensure all corridor rectangles form a single connected set by adding L-shaped connectors
local function connectCorridors(corridors: {Rect}, footprint: Rect, cw: number)
    if #corridors == 0 then return corridors end
    -- pick root as corridor nearest to building center (0,0) in local space
    local rootIndex = 1
    local bestD = math.huge
    for i, c in ipairs(corridors) do
        local cx, cz = centerOf(c)
        local d = math.abs(cx) + math.abs(cz)
        if d < bestD then bestD = d; rootIndex = i end
    end

    local function recomputeReachable()
        local reachable = {}
        local queue = { rootIndex }
        reachable[rootIndex] = true
        local qi = 1
        while qi <= #queue do
            local i = queue[qi]; qi = qi + 1
            for j = 1, #corridors do
                if not reachable[j] then
                    if rectsOverlap(corridors[i], corridors[j], 0.0) then
                        reachable[j] = true
                        queue[#queue + 1] = j
                    end
                end
            end
        end
        return reachable
    end

    local MAX_CONNECTORS = 64
    local added = 0
    while true do
        local reachable = recomputeReachable()
        local allReachable = true
        local targetIndex = nil
        for i = 1, #corridors do
            if not reachable[i] then
                allReachable = false
                targetIndex = i
                break
            end
        end
        if allReachable or added >= MAX_CONNECTORS then break end

        -- Find nearest reachable corridor to connect to
        local tx, tz = centerOf(corridors[targetIndex])
        local nearestIndex, nearestDist = nil, math.huge
        for i = 1, #corridors do
            if reachable[i] then
                local cx, cz = centerOf(corridors[i])
                local d = math.abs(cx - tx) + math.abs(cz - tz)
                if d < nearestDist then nearestDist, nearestIndex = d, i end
            end
        end
        if not nearestIndex then break end
        local nx, nz = centerOf(corridors[nearestIndex])

        -- L-shaped connection: first along X at z=tz, then along Z at x=nx
        local aX0 = math.min(tx, nx)
        local aX1 = math.max(tx, nx)
        local connA = makeRect(aX0, tz - cw * 0.5, aX1, tz + cw * 0.5)
        local bZ0 = math.min(tz, nz)
        local bZ1 = math.max(tz, nz)
        local connB = makeRect(nx - cw * 0.5, bZ0, nx + cw * 0.5, bZ1)

        corridors[#corridors + 1] = connA
        corridors[#corridors + 1] = connB
        added = added + 2
    end

    return corridors
end

-- Ensure that every room has a doorway to a corridor that is connected
local function ensureRoomAccess(rooms: {Rect}, corridors: {Rect}, doors, cfg)
    local function edgeKey(edge: Edge)
        local function r(v) return string.format("%.2f", v) end
        return table.concat({ edge.axis, r(edge.pos), r(edge.s), r(edge.e) }, ":")
    end

    -- Precompute corridor connectivity (treat touching as connected)
    local reachable = {}
    local queue = { 1 }
    if #corridors == 0 then return doors end
    reachable[1] = true
    local qi = 1
    while qi <= #queue do
        local i = queue[qi]; qi += 1
        for j = 1, #corridors do
            if not reachable[j] then
                if rectsOverlap(corridors[i], corridors[j], 1e-3) then
                    reachable[j] = true
                    queue[#queue + 1] = j
                end
            end
        end
    end

    local minW = math.max(cfg.Door.Width or 6, cfg.Door.MinWidth or 0)
    local added = 0
    for ri, room in ipairs(rooms) do
        local candidate = nil
        local bestLen = -1
        -- If a door already exists on any edge, skip
        local hasDoor = false
        for ci, hall in ipairs(corridors) do
            local e = sharedEdge(room, hall)
            if e then
                if doors[edgeKey(e)] then
                    hasDoor = true; break
                end
                local len = e.e - e.s
                if reachable[ci] and len > bestLen then
                    candidate, bestLen = e, len
                end
            end
        end
        if not hasDoor and candidate and bestLen > 1 then
            local width = math.min(minW, bestLen - 0.2)
            local center = (candidate.s + candidate.e) * 0.5
            doors[edgeKey(candidate)] = { center = center, width = math.max(2, width) }
            added += 1
        end
    end
    if added > 0 and cfg.Debug and cfg.Debug.Print then
        warn(string.format("[Generator] ensureRoomAccess added %d fallback doors", added))
    end
    return doors
end

-- Enforce minimum spacing between doors along the same wall line, then re-ensure access per room
local function enforceDoorSpacing(rooms: {Rect}, corridors: {Rect}, doors, cfg)
    local minSpacing = (cfg.Door and cfg.Door.MinSpacing) or 0
    if minSpacing <= 0 then return doors end

    local function lineKeyFromEdge(axis, pos)
        return axis .. ":" .. string.format("%.3f", pos)
    end
    local function edgeKey(edge: Edge)
        local function r(v) return string.format("%.2f", v) end
        return table.concat({ edge.axis, r(edge.pos), r(edge.s), r(edge.e) }, ":")
    end

    -- Bucket doors per line
    local perLine = {}
    for k, d in pairs(doors) do
        local axis, pos = string.match(k, "^(%a):([%d%.-]+):")
        if axis and pos then
            local lk = axis .. ":" .. pos
            local arr = perLine[lk]
            if not arr then arr = {}; perLine[lk] = arr end
            -- Extract center from key by re-parsing is brittle; store from d
            arr[#arr + 1] = { key = k, center = d.center, width = d.width }
        end
    end

    local kept = {}
    for lk, arr in pairs(perLine) do
        table.sort(arr, function(a,b) return a.center < b.center end)
        local last = -math.huge
        for _, item in ipairs(arr) do
            if item.center - last >= minSpacing then
                kept[item.key] = doors[item.key]
                last = item.center
            end
        end
    end

    -- Re-ensure each room has at least one door after spacing filter
    local filtered = kept
    local minW = math.max(cfg.Door.Width or 6, cfg.Door.MinWidth or 0)
    for _, room in ipairs(rooms) do
        local has = false
        local candidate, bestLen
        for _, hall in ipairs(corridors) do
            local e = sharedEdge(room, hall)
            if e then
                if filtered[edgeKey(e)] then has = true; break end
                local len = e.e - e.s
                if len > (bestLen or -1) then bestLen = len; candidate = e end
            end
        end
        if not has and candidate and bestLen and bestLen > 1 then
            local width = math.min(minW, bestLen - 0.2)
            local center = (candidate.s + candidate.e) * 0.5
            filtered[edgeKey(candidate)] = { center = center, width = math.max(2, width) }
        end
    end

    return filtered
end

-- Final pass: ensure the graph of corridors + rooms (via doors) is a single component.
-- Adds a single fallback door per unreachable room on its longest shared edge to any corridor
-- Iterate up to a safety cap to converge.
local function ensureGlobalConnectivity(rooms: {Rect}, corridors: {Rect}, doors, cfg)
    local function edgeKey(edge: Edge)
        local function r(v) return string.format("%.2f", v) end
        return table.concat({ edge.axis, r(edge.pos), r(edge.s), r(edge.e) }, ":")
    end

    local minW = math.max(cfg.Door.Width or 6, cfg.Door.MinWidth or 0)

    local function computeReachable()
        local rc = #corridors
        if rc == 0 then return {}, {} end
        local reachableC = table.create(rc, false)
        local reachableR = table.create(#rooms, false)
        local q = {}

        local root = 1
        reachableC[root] = true
        q[#q + 1] = { t = "c", i = root }

        while #q > 0 do
            local cur = table.remove(q, 1)
            if cur.t == "c" then
                local i = cur.i
                -- corridor->corridor
                for j = 1, rc do
                    if not reachableC[j] and rectsOverlap(corridors[i], corridors[j], 1e-3) then
                        reachableC[j] = true
                        q[#q + 1] = { t = "c", i = j }
                    end
                end
                -- corridor->room via existing doors
                for r = 1, #rooms do
                    if not reachableR[r] then
                        local e = sharedEdge(rooms[r], corridors[i])
                        if e and doors[edgeKey(e)] then
                            reachableR[r] = true
                            q[#q + 1] = { t = "r", i = r }
                        end
                    end
                end
            else
                local r = cur.i
                -- room->corridor via existing doors
                for j = 1, rc do
                    if not reachableC[j] then
                        local e = sharedEdge(rooms[r], corridors[j])
                        if e and doors[edgeKey(e)] then
                            reachableC[j] = true
                            q[#q + 1] = { t = "c", i = j }
                        end
                    end
                end
            end
        end
        return reachableR, reachableC
    end

    local MAX_ITERS = 24
    for _ = 1, MAX_ITERS do
        local reachableR, reachableC = computeReachable()
        local allOk = true
        for ri = 1, #rooms do
            if not reachableR[ri] then allOk = false break end
        end
        if allOk then break end

        -- Add fallback door for first unreachable room
        for ri = 1, #rooms do
            if not reachableR[ri] then
                local best, bestLen
                for cj = 1, #corridors do
                    -- Prefer corridors that are reachable in current graph
                    if reachableC[cj] then
                        local e = sharedEdge(rooms[ri], corridors[cj])
                        if e then
                            local len = e.e - e.s
                            if len > (bestLen or -1) then best, bestLen = e, len end
                        end
                    end
                end
                if best and bestLen and bestLen > 1 then
                    local width = math.min(minW, bestLen - 0.2)
                    local center = (best.s + best.e) * 0.5
                    doors[edgeKey(best)] = { center = center, width = math.max(2, width) }
                end
                break
            end
        end
    end

    return doors
end

-- Emit interior walls for room<->corridor borders with door holes
local function emitInteriorWalls(container: Instance, rooms: {Rect}, halls: {Rect}, doors, cfg, openingsFolder)
    local color = cfg.Colors.InteriorWalls or cfg.Colors.Walls
    local mats = cfg.Materials or {}
    local mat = mats.InteriorWalls or mats.Walls or Enum.Material.Concrete
    local thick = cfg.WallThickness
    local runPad = math.max(0, (cfg.Door and cfg.Door.Clearance) or 0) -- extra along-wall clearance

    -- Aggregate coverage and openings per unique edge line to avoid seams between adjacent corridor slices
    local lines = {} -- key -> { axis=..., pos=..., covers={}, opens={} }
    local function lineKey(axis, pos)
        return axis .. ":" .. string.format("%.3f", pos)
    end

    for _, room in ipairs(rooms) do
        for _, hall in ipairs(halls) do
            local edge = sharedEdge(room, hall)
            if edge then
                local key = lineKey(edge.axis, edge.pos)
                local entry = lines[key]
                if not entry then
                    entry = { axis = edge.axis, pos = edge.pos, covers = {}, opens = {} }
                    lines[key] = entry
                end
                table.insert(entry.covers, { s = edge.s, e = edge.e })

                -- door opening on this edge
                local function dKey(e: Edge)
                    local function r(v) return string.format("%.2f", v) end
                    return table.concat({ e.axis, r(e.pos), r(e.s), r(e.e) }, ":")
                end
                local d = doors[dKey(edge)]
                if d then
                    local s = d.center - d.width * 0.5 - runPad
                    local e = d.center + d.width * 0.5 + runPad
                    table.insert(entry.opens, { s = s, e = e })
                end
            end
        end
    end

    -- Merge intervals utility
    local function mergeIntervals(ints)
        table.sort(ints, function(a, b) return a.s < b.s end)
        local out = {}
        for _, iv in ipairs(ints) do
            if #out == 0 or iv.s > out[#out].e then
                out[#out + 1] = { s = iv.s, e = iv.e }
            else
                out[#out].e = math.max(out[#out].e, iv.e)
            end
        end
        return out
    end

    for _, entry in pairs(lines) do
        local covers = mergeIntervals(entry.covers)
        local opens = entry.opens
        -- For each cover span, subtract openings and emit one continuous band (full height) to avoid vertical seams
        for _, cov in ipairs(covers) do
            local kept = subtractIntervals(cov.s, cov.e, opens)
            for _, seg in ipairs(kept) do
                local edge = { axis = entry.axis, pos = entry.pos, s = seg.s, e = seg.e }
                emitWallBandParts(container, color, edge, 0, cfg.WallHeight, {}, thick, mat)
            end
        end
        -- Create board-up proxies for each opening on this line (passages)
        if openingsFolder then
            for _, iv in ipairs(opens) do
                local s, e = iv.s, iv.e
                if e > s then
                    local mid = (s + e) * 0.5
                    local len = e - s
                    local h = cfg.WallHeight
                    local thickLocal = math.max(0.2, cfg.WallThickness - 0.05)
                    local p = Instance.new("Part")
                    p.Name = "Opening_Passage"
                    p.Anchored = true
                    p.CanCollide = false
                    p.Transparency = 1
                    p.Material = Enum.Material.Air
                    if entry.axis == "x" then
                        p.Size = Vector3.new(len, h, thickLocal)
                        p.CFrame = CFrame.new(mid, h * 0.5, entry.pos)
                    else
                        p.Size = Vector3.new(thickLocal, h, len)
                        p.CFrame = CFrame.new(entry.pos, h * 0.5, mid)
                    end
                    p:SetAttribute("Axis", entry.axis)
                    p:SetAttribute("Pos", entry.pos)
                    p:SetAttribute("S", s)
                    p:SetAttribute("E", e)
                    p:SetAttribute("Y0", 0)
                    p:SetAttribute("Y1", h)
                    p:SetAttribute("Kind", "Passage")
                    p.Parent = openingsFolder

                    local boardCfg = cfg.BOARDUP or {}
                    local prompt = Instance.new("ProximityPrompt")
                    prompt.ActionText = "Board Up"
                    prompt.ObjectText = "Passage"
                    prompt.HoldDuration = boardCfg.Hold or 0.2
                    prompt.MaxActivationDistance = boardCfg.Distance or 12
                    prompt.KeyboardKeyCode = boardCfg.KeyCode or Enum.KeyCode.E
                    prompt.RequiresLineOfSight = false
                    prompt.Parent = p
                end
            end
        end
    end
end

-- Emit exterior walls with doors and window openings
local function emitExteriorWalls(container: Instance, footprint: Rect, exteriorDoors, cfg, interiorEdges, openingsFolder)
    local color = cfg.Colors.Walls
    local mats = cfg.Materials or {}
    local mat = mats.Walls or Enum.Material.Concrete
    local doorH = cfg.Door.Height
    local sill = cfg.Window.SillHeight
    local wTop = sill + cfg.Window.Height
    local thick = cfg.WallThickness
    local edges = gatherExteriorEdges(footprint)

    local function unionIntervals(a, b)
        if #a == 0 then return b end
        if #b == 0 then return a end
        local out = {}
        for i = 1, #a do out[#out + 1] = a[i] end
        for i = 1, #b do out[#out + 1] = b[i] end
        return out
    end

    local clearance = (cfg.Window and (cfg.Window.JunctionClearance or 0)) or 0
    if clearance <= 0 then clearance = math.max(cfg.WallThickness, 2) end

    for _, edge in ipairs(edges) do
        local doorIntervals = {}
        for _, d in ipairs(exteriorDoors) do
            if (d.axis == "x" and edge.axis == "x" and math.abs(d.pos - edge.pos) < 1e-3)
                or (d.axis == "z" and edge.axis == "z" and math.abs(d.pos - edge.pos) < 1e-3) then
                table.insert(doorIntervals, { s = d.center - d.width * 0.5, e = d.center + d.width * 0.5 })
            end
        end

        local windowIntervals = computeExteriorWindows(edge, cfg)
        -- Drop any windows too close to interior wall junctions
        local exclusions = computeJunctionExclusionsForEdge(edge, interiorEdges or {}, footprint, clearance)
        if #exclusions > 0 then
            local filtered = {}
            for _, w in ipairs(windowIntervals) do
                local keep = true
                for _, ex in ipairs(exclusions) do
                    local s = math.max(w.s, ex.s)
                    local e = math.min(w.e, ex.e)
                    if e > s then keep = false; break end
                end
                if keep then table.insert(filtered, w) end
            end
            windowIntervals = filtered
        end

        -- Non-overlapping vertical bands to avoid blocking doors with window bands
        local y0 = 0
        local yA1 = math.min(doorH, sill)
        local yB0 = yA1
        local yB1 = math.max(doorH, sill)
        local yC0 = yB1
        local yC1 = wTop
        local yD0 = math.max(doorH, wTop)
        local yTop = cfg.WallHeight

        if yA1 > y0 then
            emitWallBandParts(container, color, edge, y0, yA1, doorIntervals, thick, mat)
        end
        if yB1 > yB0 then
            emitWallBandParts(container, color, edge, yB0, yB1, unionIntervals(doorIntervals, windowIntervals), thick, mat)
        end
        if yC1 > yC0 then
            emitWallBandParts(container, color, edge, yC0, yC1, windowIntervals, thick, mat)
        end
        if yTop > yD0 then
            emitWallBandParts(container, color, edge, yD0, yTop, {}, thick, mat)
        end
        -- Register openings for board-up
        if openingsFolder then
            local function register(kind, interval, oy0, oy1)
                local s, e = interval.s, interval.e
                if e <= s then return end
                local mid = (s + e) * 0.5
                local h = math.max(0.1, oy1 - oy0)
                local len = e - s
                local thickLocal = math.max(0.2, cfg.WallThickness - 0.05)
                local p = Instance.new("Part")
                p.Name = string.format("Opening_%s", kind)
                p.Anchored = true
                p.CanCollide = false
                p.Transparency = 1
                p.Material = Enum.Material.Air
                if edge.axis == "x" then
                    p.Size = Vector3.new(len, h, thickLocal)
                    p.CFrame = CFrame.new(mid, oy0 + h * 0.5, edge.pos)
                else
                    p.Size = Vector3.new(thickLocal, h, len)
                    p.CFrame = CFrame.new(edge.pos, oy0 + h * 0.5, mid)
                end
                p:SetAttribute("Axis", edge.axis)
                p:SetAttribute("Pos", edge.pos)
                p:SetAttribute("S", s)
                p:SetAttribute("E", e)
                p:SetAttribute("Y0", oy0)
                p:SetAttribute("Y1", oy1)
                p:SetAttribute("Kind", kind)
                p.Parent = openingsFolder

                local boardCfg = cfg.BOARDUP or {}
                local prompt = Instance.new("ProximityPrompt")
                prompt.ActionText = "Board Up"
                prompt.ObjectText = kind
                prompt.HoldDuration = boardCfg.Hold or 0.2
                prompt.MaxActivationDistance = boardCfg.Distance or 12
                prompt.KeyboardKeyCode = boardCfg.KeyCode or Enum.KeyCode.E
                prompt.RequiresLineOfSight = false
                prompt.Parent = p
            end
            for _, d in ipairs(doorIntervals) do register("DoorExterior", d, 0, doorH) end
            for _, w in ipairs(windowIntervals) do register("Window", w, sill, wTop) end
        end
    end
end

-- Emit solid walls between room-room shared borders (no door openings)
local function emitRoomToRoomWalls(container: Instance, rooms: {Rect}, cfg)
    local color = cfg.Colors.InteriorWalls or cfg.Colors.Walls
    local thick = cfg.WallThickness
    local h = cfg.WallHeight
    for i = 1, #rooms do
        for j = i + 1, #rooms do
            local a = rooms[i]
            local b = rooms[j]
            local edge = sharedEdge(a, b)
            if edge then
                emitWallBandParts(container, color, edge, 0, h, {}, thick)
            end
        end
    end
end

-- Optional debug: visualize rectangles as thin parts
local function visualizeRects(container: Instance, rooms: {Rect}, halls: {Rect}, cfg)
    if not (cfg.Debug and cfg.Debug.VisualizeRects) then return end
    local function addRect(r: Rect, color: Color3, y: number)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 0.6
        p.Color = color
        local cx, cz = rectCenter(r)
        p.Size = Vector3.new(math.max(0.2, rectWidth(r) - 0.4), 0.2, math.max(0.2, rectLength(r) - 0.4))
        p.CFrame = CFrame.new(cx, y, cz)
        p.Parent = container
    end
    for _, r in ipairs(rooms) do addRect(r, Color3.fromRGB(100, 200, 100), 0.2) end
    for _, h in ipairs(halls) do addRect(h, Color3.fromRGB(200, 100, 100), 0.4) end
end

-- Emit flat floor parts for corridors/rooms (optional)
local function emitFloors(container: Instance, rects: {Rect}, color: Color3, material: Enum.Material?, yOffset: number)
    for _, r in ipairs(rects) do
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Color = color
        if material then p.Material = material end
        local cx, cz = rectCenter(r)
        p.Size = Vector3.new(rectWidth(r), 0.2, rectLength(r))
        p.CFrame = CFrame.new(cx, 0.1 + (yOffset or 0), cz)
        p.Parent = container
    end
end

local function emitSlab(container: Instance, name: string, rect: Rect, wallThick: number, extend: number, y: number, thickness: number, color: Color3, material: Enum.Material?, fillUnderExteriorWalls: boolean?)
    local x0, x1, z0, z1
    if fillUnderExteriorWalls then
        -- Expand to include area beneath exterior walls
        x0 = rect.x0 - wallThick * 0.5 - (extend or 0)
        x1 = rect.x1 + wallThick * 0.5 + (extend or 0)
        z0 = rect.z0 - wallThick * 0.5 - (extend or 0)
        z1 = rect.z1 + wallThick * 0.5 + (extend or 0)
    else
        -- Shrink so we DO NOT place slab under exterior walls
        x0 = rect.x0 + wallThick * 0.5 + (extend or 0)
        x1 = rect.x1 - wallThick * 0.5 - (extend or 0)
        z0 = rect.z0 + wallThick * 0.5 + (extend or 0)
        z1 = rect.z1 - wallThick * 0.5 - (extend or 0)
    end
    local cx = (x0 + x1) * 0.5
    local cz = (z0 + z1) * 0.5
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Color = color
    if material then p.Material = material end
    p.Size = Vector3.new(math.max(0.2, x1 - x0), thickness, math.max(0.2, z1 - z0))
    p.CFrame = CFrame.new(cx, y + thickness * 0.5, cz)
    p.Parent = container
end

-- Public API: Generate a building Model at originCFrame (floor aligned), returns the created Model
function Generator.Generate(originCFrame: CFrame, cfg)
    assert(originCFrame ~= nil, "originCFrame required")
    assert(cfg ~= nil, "cfg required")

    local rng = Random.new(cfg.Seed or os.clock())
    local fpW = cfg.Footprint.Width
    local fpL = cfg.Footprint.Length
    local halfW = fpW * 0.5
    local halfL = fpL * 0.5

    -- Build in local space centered at (0,0); we will transform to origin at the end
    local footprint = makeRect(-halfW, -halfL, halfW, halfL)

    local rooms, corridors = bspPartition(rng, footprint, cfg)
    local extDoors
    extDoors, corridors = planExteriorDoorsAndEntrances(rng, footprint, corridors, cfg)
    -- Force corridor graph to be connected to avoid isolated areas
    corridors = connectCorridors(corridors, footprint, cfg.CorridorWidth)
    local doors = planDoors(rng, rooms, corridors, cfg)
    doors = ensureRoomAccess(rooms, corridors, doors, cfg)
    doors = enforceDoorSpacing(rooms, corridors, doors, cfg)
    doors = ensureGlobalConnectivity(rooms, corridors, doors, cfg)

    local model = Instance.new("Model")
    model.Name = "GeneratedBuilding"

    local wallsFolder = Instance.new("Folder"); wallsFolder.Name = "Walls"; wallsFolder.Parent = model
    local floorsFolder = Instance.new("Folder"); floorsFolder.Name = "Floors"; floorsFolder.Parent = model
    local roofFolder = Instance.new("Folder"); roofFolder.Name = "Roof"; roofFolder.Parent = model
    local openingsFolder = Instance.new("Folder"); openingsFolder.Name = "Openings"; openingsFolder.Parent = model

    visualizeRects(model, rooms, corridors, cfg)

    if cfg.GenerateFloors then
        local mats = cfg.Materials or {}
        local offset = (cfg.Slab and cfg.Slab.FloorOffset) or 0
        emitFloors(floorsFolder, rooms, cfg.Colors.Rooms, mats.Floor or Enum.Material.Wood, offset)
        emitFloors(floorsFolder, corridors, cfg.Colors.Corridors, mats.Floor or Enum.Material.Wood, offset)
    end

    -- Single floor slab under everything
    if cfg.GenerateFloorSlab ~= false then
        local slabCfg = cfg.Slab or { FloorThickness = 1, Extend = 0 }
        local mats = cfg.Materials or {}
        local offset = slabCfg.FloorOffset or 0
        -- Do not place floor under exterior walls: pass fillUnderExteriorWalls=false
        emitSlab(floorsFolder, "FloorSlab", footprint, cfg.WallThickness, slabCfg.Extend or 0, 0 + offset, slabCfg.FloorThickness or 1, cfg.Colors.Floor or cfg.Colors.Rooms, mats.Floor or Enum.Material.Wood, false)
    end

    -- Single roof slab above everything
    if cfg.GenerateRoof ~= false then
        local slabCfg = cfg.Slab or { RoofThickness = 1, Extend = 0 }
        local mats = cfg.Materials or {}
        local yTop = cfg.WallHeight
        -- Roof can extend under exterior walls for better coverage
        emitSlab(roofFolder, "RoofSlab", footprint, cfg.WallThickness, slabCfg.Extend or 0, yTop, slabCfg.RoofThickness or 1, cfg.Colors.Roof or cfg.Colors.Walls, mats.Roof or Enum.Material.SmoothPlastic, true)
    end

    -- Interior walls between rooms and corridors
    emitInteriorWalls(wallsFolder, rooms, corridors, doors, cfg, openingsFolder)
    -- Exterior walls with windows and exterior doors
    local interiorEdges = gatherInteriorEdges(rooms, corridors)
    emitExteriorWalls(wallsFolder, footprint, extDoors, cfg, interiorEdges, openingsFolder)

    -- Compute largest room center (in local space), then transform to world space
    local largestArea = -1
    local largestCenterLocal: Vector3? = nil
    for _, r in ipairs(rooms) do
        local area = rectWidth(r) * rectLength(r)
        if area > largestArea then
            largestArea = area
            local cx, cz = rectCenter(r)
            largestCenterLocal = Vector3.new(cx, 0, cz)
        end
    end

    local largestCenterWorld: Vector3? = nil
    if largestCenterLocal then
        largestCenterWorld = originCFrame:ToWorldSpace(CFrame.new(largestCenterLocal)).Position
    end

    -- Determine floor top in local space (slab vs patches)
    local slabOffset = (cfg.Slab and cfg.Slab.FloorOffset) or 0
    local slabThickness = (cfg.Slab and cfg.Slab.FloorThickness) or 1
    local haveSlab = (cfg.GenerateFloorSlab ~= false)
    local havePatches = (cfg.GenerateFloors == true)

    local slabTopLocal = haveSlab and (slabThickness + slabOffset) or 0
    local slabTopLocalBase = haveSlab and (slabThickness) or 0
    local patchTopLocal = havePatches and (0.2 + slabOffset) or 0
    local patchTopLocalBase = havePatches and 0.2 or 0

    local floorTopLocal = math.max(slabTopLocal, patchTopLocal)
    local floorBaseLocal = math.max(slabTopLocalBase, patchTopLocalBase)
    local floorTopWorld = originCFrame.Position.Y + floorTopLocal
    local floorBaseWorld = originCFrame.Position.Y + floorBaseLocal

    -- Transform to originCFrame (rotation+translation); since we only used identity rotation, apply the full CFrame to children
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            inst.CFrame = originCFrame:ToWorldSpace(inst.CFrame)
        end
    end

    model.Parent = Workspace
    return model, { largestRoomCenter = largestCenterWorld, floorTopY = floorTopWorld, floorBaseY = floorBaseWorld }
end

return Generator
