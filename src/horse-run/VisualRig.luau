-- Cached joint graph for local display clones. Original assets are never edited.
local VisualRig = {}
function VisualRig.capture(model, root)
    local graph, parts, edges = {}, {}, {}
    for _, d in model:GetDescendants() do
        if d:IsA('BasePart') then
            d.Anchored=true; d.CanCollide=false; d.CanTouch=false; d.CanQuery=false
            d.LocalTransparencyModifier=0
            graph[d]={}; table.insert(parts,{part=d,size=d.Size,rest=root.CFrame:ToObjectSpace(d.CFrame)})
        elseif d:IsA('BaseScript') then d.Disabled=true
        elseif d:IsA('Animator') then
            for _,track in d:GetPlayingAnimationTracks() do track:Stop(0) end
        end
    end
    for _,d in model:GetDescendants() do
        local attachmentJoint=d:IsA('AnimationConstraint') or d:IsA('RigidConstraint')
        if d:IsA('JointInstance') or d:IsA('WeldConstraint') or attachmentJoint then
            local a,b
            if attachmentJoint then
                a=d.Attachment0 and d.Attachment0.Parent;b=d.Attachment1 and d.Attachment1.Parent
            else a=d.Part0;b=d.Part1 end
            if graph[a] and graph[b] then
                local edge={a=a,b=b,name=d.Name,motor=d:IsA('Motor6D') or d:IsA('AnimationConstraint'),offset=a.CFrame:ToObjectSpace(b.CFrame)}
                if edge.motor then edge.c0=d.C0; edge.c1=d.C1 end
                table.insert(graph[a],edge);table.insert(graph[b],edge)
            end
            -- All display parts are posed explicitly; physics and Animator cannot fight the pose.
            d.Enabled=false
        elseif d:IsA('Constraint') then
            d.Enabled=false
        end
    end
    local visited={[root]=true};local queue={root};local i=1
    while queue[i] do
        local p=queue[i];i+=1
        for _,edge in graph[p] or {} do
            local other=edge.a==p and edge.b or edge.a
            if not visited[other] then
                visited[other]=true;table.insert(queue,other)
                table.insert(edges,{from=p,to=other,edge=edge,reverse=edge.b==p})
            end
        end
    end
    return {root=root,parts=parts,edges=edges,poses={},lastScale=nil}
end
function VisualRig.pose(rig, rootCF, offsets, scale)
    scale=scale or Vector3.one
    local poses=rig.poses;poses[rig.root]=CFrame.identity
    for _,link in rig.edges do
        local edge=link.edge
        local relative=edge.motor and (edge.c0*(offsets[edge.name] or CFrame.identity)*edge.c1:Inverse()) or edge.offset
        poses[link.to]=poses[link.from]*(link.reverse and relative:Inverse() or relative)
    end
    for _,entry in rig.parts do
        local cf=poses[entry.part] or entry.rest
        local position=cf.Position*scale
        local rotation=cf.Rotation
        if scale~=Vector3.one then
            local up=(cf.YVector*scale).Unit
            local right=up:Cross(cf.ZVector*scale).Unit
            rotation=CFrame.fromMatrix(Vector3.zero,right,up,right:Cross(up))
        end
        entry.part.CFrame=rootCF*CFrame.new(position)*rotation
        if scale~=Vector3.one or rig.lastScale~=Vector3.one then
            entry.part.Size=entry.size*Vector3.new((cf.XVector*scale).Magnitude,(cf.YVector*scale).Magnitude,(cf.ZVector*scale).Magnitude)
        end
    end
    rig.lastScale=scale
end
return VisualRig
