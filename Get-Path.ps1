 $_ = env | sls PATH -CaseSensitive | ConvertFrom-StringData -Delimiter = | select -ExpandProperty Values
 $_ -split ":"