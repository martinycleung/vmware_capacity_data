#PowerCLI script for vSphere capacity planning

First created by Marc Vincent Davoli and released in the VMWare forum
https://communities.vmware.com/thread/467442?start=45&tstart=0

This modifies the output to create a JSON object, output resembles

```
[
    {
        "total_ram":  588,                                                                    #measured in GB
        "dc_count":  1,
        "description":  "VMWare Capacity \u0026 Performance Report for SERVER_NAME",
        "servername":  "SERVER_NAME",
        "memory":  [
                       {
                           "total_ram":  48,                                                  #measured in GB
                           "host":  "127.0.0.1",
                           "avg_mem_usage":  0.45,                                            # %
                           "cur_mem_usage":  0.45                                             # %
                       },
                       { ... }
                   ],
        "cpu":  [
                    {
                        "cur_cpu_usage":  0.02,                                              # %
                        "host":  "127.0.0.1",
                        "avg_cpu_usage":  0.02,                                              # %
                        "cpu_count":  8
                    },
                    { ... }
                ],
        "cpu_count":  106,
        "version":  null,
        "total_cpu":  231,                                                                    #measured in GHz
        "hardware":  [
                         {
                             "model":  "Hardware Vendor R000-000000000",
                             "version":  "5.1.0 Build 2323236",
                             "uptime":  31,                                                   #measured in Days
                             "total_ram":  48,                                                #measured in GB
                             "host":  "127.0.0.1",
                             "cpu_count":  8
                         },
                         { ... }
                     ],
        "vtype":  "server",
        "template_count":  4,
        "host_count":  11,
        "consolidation_ratio":  "9:1",
        "vm":  {
                   "win":  7,
                   "other":  55,
                   "total":  105,
                   "nix":  43
               },
        "recource_pool_count":  3,
        "cluster_count":  3,
        "vms_count":  105,
        "timestamp":  1470760604
    },
    {
        "clustername":  "CLUSTER_NAME",
        "servername":  "SERVER_NAME",
        "resilency":  {
                          "message":  "This cluster can survive the loss of approximately 0 host(s)",
                          "ace_policy":  "N/A",
                          "ace_enabled":  "true",
                          "ha_enabled":  "false"
                      },
        "cpu":  [
                    {
                        "cur_cpu_usage":  0.03,                                               # %
                        "host":  "127.0.0.1",
                        "avg_cpu_usage":  0.02,                                               # %
                        "cpu_count":  8
                    },
                    { ... }
                ],
        "datastore":  [
                          {
                              "cur_disk_usage":  0.51,                                        # %
                              "total_vms":  1,
                              "commitment":  0.51,                                            # %
                              "name":  "datastore1 (5)",
                              "total_space":  106                                             #measured in GB
                          },
                          { ... }
                      ],
        "memory":  [
                       {
                           "total_ram":  48,                                                  #measured in GB
                           "host":  "127.0.0.1",
                           "avg_mem_usage":  0.45,                                            # %
                           "cur_mem_usage":  0.45                                             # %
                       },
                       { ... }
                   ],
        "timestamp":  1470760862,
        "provisioning":  {
                             "message":  "The approximate number of Virtual Machines you can provision safely in this cluster is 1. Memory is your limiting factor.",
                             "total_vms":  11,
                             "avg_mem_usage":  0.86,                                          # %
                             "avg_disk_usage":  56,                                           #measured in GB
                             "total_cpu_slots":  371,
                             "total_disk_slots":  18,
                             "avg_cpu_usage":  0.05,                                          # %
                             "total_memory_slots":  1
                         },
        "hardware":  {
                         "total_ram":  80,                                                    #measured in GB
                         "recource_pool_count":  1,
                         "total_space":  1395,                                                #measured in GB
                         "vms_count":  11,
                         "total_cpu":  38,
                         "datastore_count":  3,
                         "host_count":  2,
                         "cpu_count":  16,
                         "consolidation_ratio":  "5:1"
                     },
        "vtype":  "cluster"
    },
    { ... }
]

```
The JSON object does not contain comments, this example has been annotated for clarity

