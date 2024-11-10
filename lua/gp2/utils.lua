-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Various utils
-- ----------------------------------------------------------------------------

GP2.Utils = {}

if SERVER then
    
else
    function GP2.Utils.AddFace(resultTable, v1, v2, v3, v4, uv1, uv2, uv3, uv4)
        table.insert(resultTable, { pos = v1, u = uv1[1], v = uv1[2] })
        table.insert(resultTable, { pos = v2, u = uv2[1], v = uv2[2] })
        table.insert(resultTable, { pos = v3, u = uv3[1], v = uv3[2] })
    
        table.insert(resultTable, { pos = v3, u = uv3[1], v = uv3[2] })
        table.insert(resultTable, { pos = v4, u = uv4[1], v = uv4[2] })
        table.insert(resultTable, { pos = v1, u = uv1[1], v = uv1[2] })
    end

    function GP2.Utils.ToViewModelPosition(vOrigin)
        local view = render.GetViewSetup()
        local vEyePos = view.origin
        local aEyesRot = view.angles
        local vOffset = vOrigin - vEyePos
        local vForward = aEyesRot:Forward()
    
        local nViewX = math.tan(view.fovviewmodel_unscaled * math.pi / 360)
        local nWorldX = math.tan(view.fov_unscaled * math.pi / 360)
    
        if (nViewX == 0 or nWorldX == 0) then
            return vEyePos + vForward * vForward:Dot(vOffset)
        end
    
        local nFactor = nViewX / nWorldX
    
        return vEyePos
            + aEyesRot:Right() * (aEyesRot:Right():Dot(vOffset) * nFactor)
            + aEyesRot:Up() * (aEyesRot:Up():Dot(vOffset) * nFactor)
            + vForward * vForward:Dot(vOffset)
    end
    
end