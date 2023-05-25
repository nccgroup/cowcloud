import subprocess
import time

debug = True

def execution(tmp_folder, target, extra_docker_params):

    # extra_docker_params: this includes the information required for your container to log the output to cloudwatch, include this variable when you want to view the stdout through the frontend.
    # example: cmd = f"docker run {extra_docker_params} --rm -v {tmp_folder}target.txt:/root/Tools/reconftw/target.txt -v {tmp_folder}reconftw.cfg:/root/Tools/reconftw/reconftw.cfg -v {tmp_folder}Recon/:/root/Tools/reconftw/Recon/ six2dez/reconftw:main -l target.txt -w".split(' ')
    
    try:
        # tmp_folder => /tmp/.5241093543140349230/
        
 
        # -------------- RECONFTW
        # command = f"wget -O {tmp_folder}reconftw.cfg https://raw.githubusercontent.com/six2dez/reconftw/main/reconftw.cfg; mkdir {tmp_folder}Recon"
        # print(command)
        # ret = subprocess.run(command, stdout=subprocess.PIPE, shell=True)
        # print(ret.stdout.decode())

        # f = open(f"{tmp_folder}target.txt", "w")
        # f.write(target)
        # f.close()

        # ret = subprocess.run(command, stdout=subprocess.PIPE, shell=True)
        # print(ret.stdout.decode())       
        # # add file target.txt with the target domain to the folder root/test or tmp_folder

        # time.sleep(2)
        # # docker run -v $PWD/target.txt:/root/Tools/reconftw/target.txt -v $PWD/reconftw.cfg:/root/Tools/reconftw/reconftw.cfg -v $PWD/Recon/:/root/Tools/reconftw/Recon/ --name reconftwSCAN --rm six2dez/reconftw:main -l target.txt -w
        # cmd = f"docker run {extra_docker_params} --rm -v {tmp_folder}target.txt:/root/Tools/reconftw/target.txt -v {tmp_folder}reconftw.cfg:/root/Tools/reconftw/reconftw.cfg -v {tmp_folder}Recon/:/root/Tools/reconftw/Recon/ six2dez/reconftw:main -l target.txt -w".split(' ')
        # #cmd = f"ping -c 10 google.com".split(' ')
        # print(" ".join(cmd))
        # result = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        # -------------- RECONFTW
        # -------------- BURP

        # BURP: Create burp_payload.json
        
        output_file = f'{tmp_folder}output.nmap'
        # '-F'
        result = subprocess.Popen(['nmap', '-sT', '-sV', '-p', '443,80', '-oN', output_file, target], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if debug:
            for line in iter(result.stdout.readline, b''):
                print(line.decode("utf-8"))

        output, error = result.communicate()
        if result.returncode == 137:
            # it happens when the execution is terminate (interrupted through the web interface) 
            pass
        if result.returncode != 0: 
            error = "Error: %d %s %s" % (result.returncode, output.decode("utf-8"), error.decode("utf-8"))
            raise Exception(error)

        print("execution complete")

    except Exception as e:
        raise Exception(e)

