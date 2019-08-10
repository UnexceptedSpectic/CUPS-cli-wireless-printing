#!/bin/bash

#about
#print a file using CUPS via the command line. more options at https://www.cups.org/doc/options.html

#directions
#following the script name, arg1 = path to file; arg2 = ~/.ssh/config host or user@hostname; arg3 = page range (e.g. 1-4,7,9-12)


#definitions
parent=$(pwd)
rpath=$1
filename=$(basename $rpath)
cd "$(dirname $rpath)"
fpath_min_fn=$(pwd | sed 's/ /\\ /g')
cd "$parent"
path=$fpath_min_fn"/"$filename
server=$2
range="page-ranges=$3"
convert=false
read -s -p "Password for CUPS: " password

#doc conversion to pdf via zamar api. more info at https://developers.zamzar.com/docs
if [[ ${filename: -4} != ".pdf" ]]; then
    convert=true
    request=$(curl https://sandbox.zamzar.com/v1/jobs -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -X POST -F "source_file=@$path" -F "target_format=pdf")
    job_id=$(echo $request | jq -r ".id")
    state=$(curl https://sandbox.zamzar.com/v1/jobs/$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e:)
    status=$(echo $state | jq -r ".status")
    while [[ $status != "successful" ]]; do
        /bin/sleep 5
        state=$(curl https://sandbox.zamzar.com/v1/jobs/$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e:)
        status=$(echo $state | jq -r ".status")
    done
    target_file_id=$(echo $state | jq ".target_files[0] | .id")
    curl https://sandbox.zamzar.com/v1/files/$target_file_id/content -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -L -O -J
    pdf_ext_path=$(echo $path | cut -d'.' -f 1)".pdf"
    filename=$(basename $pdf_ext_path)
    path=./$filename
    jobs_remaining=$(curl https://api.zamzar.com/v1/jobs/$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -i | awk -F 'Zamzar-Test-Credits-Remaining:' '{print $2}')
    jobs_remaining="$(echo -e "${jobs_remaining}" | tr -d '[:space:]')"
fi

#file transfer and printing
sshpass -p $password scp $path $server:/tmp >/dev/null 2>&1
if [[ $convert == true ]]; then
    rm $path
fi

#heredoc cancer solution https://unix.stackexchange.com/a/405254/306463
sshpass -p $password ssh -o StrictHostKeyChecking=no $server /bin/bash << EOF >/dev/null 2>&1

#definitions
filename=$filename
password=$password
printer_name=\$(/usr/bin/lpstat -p -d | head -n1 | awk -F ' ' '{print \$2}')
options="-o media=Letter -o $range"

#print job and cleanup
print_command="/usr/bin/lp"
\$(\$print_command -d \$printer_name \$options /tmp/\$filename)
\$(echo \$password | sudo -S rm -r /tmp/\$filename)

EOF


echo
echo "Print job sent, $jobs_remaining zamzar conversions remain"
echo