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

## Elasticsearch version output

I flattened the JSON output a bit to be friendlier for Elasticsearch consumption


\*The measurements haven't changed


```
[{
     "total_ram":  869,
     "dc_count":  1,
     "description":  "VMWare Capacity \u0026 Performance Report for SERVER_NAME",
     "server_name":  "SERVER_ADDRESS",
     "version":  null,
     "total_cpu":  231,
     "vtype":  "server",
     "template_count":  4,
     "vms_count":  105,
     "consolidation_ratio":  "9:1",
     "vm":  {
                "win":  7,
                "other":  51,
                "total":  105,
                "nix":  47
            },
     "recource_pool_count":  3,
     "timestamp":  1471531206,
     "cluster_count":  12,
     "cpu_count":  332,
     "host_count":  50
 },
 {
    "model":  "1001001101",
    "cur_cpu_usage":  0.02,
    "avg_mem_usage":  0.46,
    "version":  "5.1.0 Build 2323236",
    "avg_cpu_usage":  0.02,
    "server_name":  "SERVER_NAME",
    "uptime":  40,
    "total_ram":  48,
    "host":  "127.0.0.1",
    "cpu_count":  8,
    "cur_mem_usage":  0.46,
    "vtype":  "host"
},{
    "total_vms":  7,
    "total_space":  1393,
    "cur_disk_usage":  0.26,
    "server_name":  "SERVER_NAME",
    "name":  "DISK_NAME",
    "commitment":  0.28,
    "vtype":  "datastore"
},{
    "cluster_name":  "CLUSTER_1",
    "total_vms":  1,
    "total_space":  106,
    "cur_disk_usage":  0.51,
    "server_name":  "SERVER_NAME",
    "name":  "DISK_NAME",
    "commitment":  0.51,
    "vtype":  "datastore"
},{
    "message":  "The approximate number of Virtual Machines you can provision safely in this cluster is 1. Memory is your limiting factor.",
    "total_vms":  11,
    "avg_mem_usage":  8.59,
    "avg_disk_usage":  56,
    "total_cpu_slots":  380,
    "server_name":  "SERVER_NAME",
    "total_disk_slots":  18,
    "avg_cpu_usage":  0.04,
    "total_memory_slots":  1,
    "cluster_name":  "CLUSTER_NAME",
    "vtype":  "provision"
},
{
    "message":  "This cluster can survive the loss of approximately 0 host(s)",
    "ha_enabled":  "false",
    "server_name":  "SERVER_NAME",
    "cluster_name":  "CLUSTER_NAME",
    "ace_policy":  "N/A",
    "ace_enabled":  "true",
    "vtype":  "resiliency"
}]
