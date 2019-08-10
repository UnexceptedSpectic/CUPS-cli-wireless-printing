#!/bin/bash

#about
#print a file using CUPS via the command line. more options at https://www.cups.org/doc/options.html

#directions
#following the script name, arg1 = path to file; arg2 = ~/.ssh/config host or user@hostname; arg3 = page range (e.g. 1-4,7,9-12)
#sshpass is not used to ensure conpatability with mobileterminal on ios

#definitions
path=$1
server=$2
read -s -p "Password for CUPS: " password
echo

#file transfer and printing
scp $path $server:/home/print 

#heredoc execution tip - https://unix.stackexchange.com/a/405254/306463
ssh -o StrictHostKeyChecking=no $server /bin/bash << EOF 

#definitions
filename=\$(basename $path)
path=\$HOME/\$filename
path1=\$HOME/\$filename
range="page-ranges=$3"
password=$password

#ensure jq is installed for parsing the JSON response for the zamzar api
if [[ \$(which jq) == "" ]]; then
    \$(echo \$password | sudo -S apt-get install jq -y)
fi

#doc conversion to pdf via zamar api. more info at https://developers.zamzar.com/docs
convert=false
if [ "\${filename: -4}" != ".pdf" ]; then
    cd \$HOME
    convert=true
    request=\$(curl https://sandbox.zamzar.com/v1/jobs -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -X POST -F "source_file=@\$path1" -F "target_format=pdf")
    job_id=\$(echo \$request | jq -r ".id")
    state=\$(curl https://sandbox.zamzar.com/v1/jobs/\$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e:)
    status=\$(echo \$state | jq -r ".status")
    while [[ \$status != "successful" ]]; do
        /bin/sleep 5
        state=\$(curl https://sandbox.zamzar.com/v1/jobs/\$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e:)
        status=\$(echo \$state | jq -r ".status")
    done
    target_file_id=\$(echo \$state | jq ".target_files[0] | .id")
    curl https://sandbox.zamzar.com/v1/files/\$target_file_id/content -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -L -O -J
    pdf_ext_path1=\$(echo \$path1 | cut -d'.' -f 1)".pdf"
    filename=\$(basename \$pdf_ext_path1)
    path=\$HOME/\$filename
    jobs_remaining=\$(curl https://api.zamzar.com/v1/jobs/\$job_id -u f08121f9540cc0e960319b6f644cbac4ffc2599e: -i | awk -F 'Zamzar-Test-Credits-Remaining:' '{print $2}')
    jobs_remaining="\$(echo -e "\${jobs_remaining}" | tr -d '[:space:]')"
fi

#print info and options
printer_name=\$(/usr/bin/lpstat -p -d | head -n1 | awk -F ' ' '{print \$2}')
options="-o media=Letter -o \$range"

#print job and cleanup
print_command="/usr/bin/lp"
\$(\$print_command -d \$printer_name \$options \$path)
\$(rm \$path1)
if [ \$convert == true ]; then
    rm \$path
fi

EOF

echo
echo "Print job sent, $jobs_remaining zamzar conversions remain"
#not sure why jobs_remaining isn't redefined correctly. heredoc crap?
echo