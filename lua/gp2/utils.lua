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
end