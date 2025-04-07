function Get-AnsibleVersion {
    $ansibleVersion = (ansible --version)[0] -replace "[^\d.]"
    return "Ansible $ansibleVersion"
}

function Get-AptFastVersion {
    $versionFileContent = Get-Content (which apt-fast) -Raw
    $match = [Regex]::Match($versionFileContent, '# apt-fast v(.+)\n')
    $aptFastVersion = $match.Groups[1].Value
    return "apt-fast $aptFastVersion"
}

function Get-AzCopyVersion {
    $azcopyVersion = azcopy --version | Take-OutputPart -Part 2
    return "AzCopy $azcopyVersion (available by ``azcopy`` and ``azcopy10`` aliases)"
}


function Get-PodManVersion {
    $podmanVersion = podman --version | Take-OutputPart -Part 2
    if ((Test-IsUbuntu18) -or (Test-IsUbuntu20)) {
        $aptSourceRepo = Get-AptSourceRepository -PackageName "containers"
        return "Podman $podmanVersion (apt source repository: $aptSourceRepo)"
    }
    return "Podman $podmanVersion"
}

function Get-BuildahVersion {
    $buildahVersion = buildah --version | Take-OutputPart -Part 2
    if ((Test-IsUbuntu18) -or (Test-IsUbuntu20)) {
        $aptSourceRepo = Get-AptSourceRepository -PackageName "containers"
        return "Buildah $buildahVersion (apt source repository: $aptSourceRepo)"
    }
    return "Buildah $buildahVersion"
}

function Get-SkopeoVersion {
    $skopeoVersion = skopeo --version | Take-OutputPart -Part 2
    if ((Test-IsUbuntu18) -or (Test-IsUbuntu20)) {
        $aptSourceRepo = Get-AptSourceRepository -PackageName "containers"
        return "Skopeo $skopeoVersion (apt source repository: $aptSourceRepo)"
    }
    return "Skopeo $skopeoVersion"
}



function Get-DockerComposeV1Version {
    $composeVersion = docker-compose -v | Take-OutputPart -Part 2 | Take-OutputPart -Part 0 -Delimiter ","
    return "Docker Compose v1 $composeVersion"
}

function Get-DockerComposeV2Version {
    $composeVersion = docker compose version | Take-OutputPart -Part 3
    return "Docker Compose v2 $composeVersion"
}

function Get-DockerMobyClientVersion {
    $dockerClientVersion = sudo docker version --format '{{.Client.Version}}'
    return "Docker-Moby Client $dockerClientVersion"
}

function Get-DockerMobyServerVersion {
    $dockerServerVersion = sudo docker version --format '{{.Server.Version}}'
    return "Docker-Moby Server $dockerServerVersion"
}

function Get-DockerBuildxVersion {
    $buildxVersion = docker buildx version  | Take-OutputPart -Part 1 | Take-OutputPart -Part 0 -Delimiter "+"
    return "Docker-Buildx $buildxVersion"
}

function Get-DockerAmazonECRCredHelperVersion {
    $ecrVersion = docker-credential-ecr-login -v | Select-String "Version:" | Take-OutputPart -Part 1
    return "Docker Amazon ECR Credential Helper $ecrVersion"
}

function Get-GitVersion {
    $gitVersion = git --version | Take-OutputPart -Part -1
    $aptSourceRepo = Get-AptSourceRepository -PackageName "git-core"
    return "Git $gitVersion (apt source repository: $aptSourceRepo)"
}

function Get-GitLFSVersion {
    $result = Get-CommandResult "git-lfs --version"
    $gitlfsversion = $result.Output | Take-OutputPart -Part 0 | Take-OutputPart -Part 1 -Delimiter "/"
    $aptSourceRepo = Get-AptSourceRepository -PackageName "git-lfs"
    return "Git LFS $gitlfsversion (apt source repository: $aptSourceRepo)"
}

function Get-GitFTPVersion {
    $gitftpVersion = git-ftp --version | Take-OutputPart -Part 2
    return "Git-ftp $gitftpVersion"
}

function Get-KustomizeVersion {
    $kustomizeVersion = kustomize version --short | Take-OutputPart -Part 0 | Take-OutputPart -Part 1 -Delimiter "v"
    return "Kustomize $kustomizeVersion"
}

function Get-KubectlVersion {
    $kubectlVersion = (kubectl version --client --output=json | ConvertFrom-Json).clientVersion.gitVersion.Replace('v','')
    return "Kubectl $kubectlVersion"
}

function Get-MinikubeVersion {
    $minikubeVersion = minikube version --short | Take-OutputPart -Part 0 -Delimiter "v"
    return "Minikube $minikubeVersion"
}

function Get-PackerVersion {
    # Packer 1.7.1 has a bug and outputs version to stderr instead of stdout https://github.com/hashicorp/packer/issues/10855
    $result = (Get-CommandResult "packer --version").Output
    $packerVersion = [regex]::matches($result, "(\d+.){2}\d+").Value
    return "Packer $packerVersion"
}

function Get-TerraformVersion {
    return (terraform version | Select-String "^Terraform").Line.Replace('v','')
}

function Get-JqVersion {
    $jqVersion = jq --version | Take-OutputPart -Part 1 -Delimiter "-"
    return "jq $jqVersion"
}

function Get-AzureCliVersion {
    $azcliVersion = (az version | ConvertFrom-Json).'azure-cli'
    $aptSourceRepo = Get-AptSourceRepository -PackageName "azure-cli"
    return "Azure CLI (azure-cli) $azcliVersion (installation method: $aptSourceRepo)"
}

function Get-AzureDevopsVersion {
    $azdevopsVersion = (az version | ConvertFrom-Json).extensions.'azure-devops'
    return "Azure CLI (azure-devops) $azdevopsVersion"
}

function Get-GitHubCliVersion {
    $ghVersion = gh --version | Select-String "gh version" | Take-OutputPart -Part 2
    return "GitHub CLI $ghVersion"
}


function Get-YamllintVersion {
    return "$(yamllint --version)"
}

function Get-YqVersion {
    $yqVersion = ($(yq -V) -Split " ")[-1]
    return "yq $yqVersion"
}