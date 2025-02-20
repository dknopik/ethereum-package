shared_utils = import_module("../shared_utils/shared_utils.star")

NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR = "/node-{0}-ssv-keys/"

def ssv_key_generator(
    plan,
    docker_cache_params,
):
    config = ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            "ssvlabs/ssv-node:latest",
        ),
        entrypoint=["sleep", "99999"],
        files={},
    )
    service_name = "ssv-key-generation"
    plan.add_service(service_name, config)
    return service_name

def prepare(plan, docker_cache_params, participants, ssv_params, ssv_keystore_files):
    service_name = ssv_key_generator(plan, docker_cache_params)
    ssv_node_count = 0

    all_output_dirpaths = []
    all_sub_command_strs = []
    ssv_node_count = 0

    for (idx, participant) in enumerate(participants):
        if participant.vc_type not in ["anchor", "go_ssv"]:
            all_output_dirpaths.append(None)
            continue
        ssv_node_count += 1
        output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx)
        generate_key_cmd = '/go/bin/ssvnode generate-operator-keys > {0}keys.log'.format(output_dirpath)
        all_sub_command_strs.append(generate_key_cmd)
        extract_sk_cmd = 'grep "generated private key (base64)" "{0}" | grep -E -o "(\{.+\})" | jq -r "{0}.sk"'.format(output_dirpath)
        all_sub_command_strs.append(extract_sk_cmd)
        extract_pk_cmd = 'grep "generated public key (base64)" "{0}" | grep -E -o "(\{.+\})" | jq -r "{0}.pk"'.format(output_dirpath)
        all_sub_command_strs.append(extract_pk_cmd)
        all_output_dirpaths.append(output_dirpath)

    command_str = " && ".join(all_sub_command_strs)

    command_result = plan.exec(
        service_name=service_name,
        description="Generating ssv keys",
        recipe=ExecRecipe(command=["sh", "-c", command_str]),
    )
    plan.verify(command_result["code"], "==", 0)


    all_ssv_contexts = []


