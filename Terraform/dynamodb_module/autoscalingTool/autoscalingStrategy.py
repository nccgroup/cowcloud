#!/usr/bin/python3

# Grace point definition: a grace point is assigned to each limit, this bit prevents scaling out due to decrasing a single task.  
#                   {"totalNodes": 2, "tasksMaxLimit": [20], "taskMinLimit": 10},
# given this limit: {"totalNodes": 3, "tasksMaxLimit":  30,  "taskMinLimit": 20}, the grace point is 15
# the grace point is calculated based on tasksMaxLimit of the previous limit. 
# totalTasks = 19 means 2 node
# totalTasks = 20 means 3 node
# totalTasks = 19 still means 3 node; the three nodes will remain until reached the grace point (15)
#
# Test:
# Total task: 20, TotalNodes: 3
# Total task: 15, TotalNodes: 3
# Total task: 14, TotalNodes: 2
# Total task: 1, TotalNodes: 1
# Total task: 10, TotalNodes: 2
# Total task: 5, TotalNodes: 2
# Total task: 4, TotalNodes: 1

import math, json
class autoscalingStrategist():

    def __init__(self, settings):
        settings=self.create_settings()
        self.lastSettings=self.query_last_settings()
        self.task_limit_to_scale_in = settings[len(settings)-1]["tasksMaxLimit"]

    def get_settings(self):
        return settings

    def create_settings(self):
        taskMinLimit = 0
        tasksMaxLimit = max_tasks_queued_per_worker
        for x in range(1, max_workers+1):
            _w = {}
            _w["totalNodes"] = x
            _w["tasksMaxLimit"] = tasksMaxLimit
            _w["taskMinLimit"] = taskMinLimit
            settings.append(_w)
            taskMinLimit = taskMinLimit + max_tasks_queued_per_worker
            tasksMaxLimit = tasksMaxLimit + max_tasks_queued_per_worker

        # Configure grace point, in other words the number of tasks before scale out to a lower level
        for i in range(len(settings)):
            if i >0:
                settings[i]['gracePoint'] = math.floor( ( settings[i-1]['taskMinLimit'] + settings[i-1]['tasksMaxLimit'] ) / 2)
        return settings

    def check(self, num_tasks):
        if num_tasks == 0:
            return 0

        nodes=0
        if num_tasks >= self.task_limit_to_scale_in:
            index=len(settings)-1
            self.lastSettings=settings[index]
            return settings[index]['totalNodes']

        if 'gracePoint' in self.lastSettings and num_tasks >= self.lastSettings['gracePoint'] and num_tasks < self.lastSettings['tasksMaxLimit']:
            nodes=self.lastSettings['totalNodes']
            return nodes
            
        for limit in settings:
            if num_tasks >= limit['taskMinLimit'] and num_tasks < limit['tasksMaxLimit']:
                nodes = limit['totalNodes']
                self.lastSettings=limit
                return nodes


    def query_last_settings(self):
        # TODO: query the database
        initial_value = 100000
        lastSettings={"totalNodes": initial_value, "tasksMaxLimit": initial_value, "taskMinLimit": initial_value, "gracePoint": initial_value}
        return lastSettings

 

    def run_test1(self):
        testingset = [20,15,14,1,10,5,4]
        for test in testingset:
            nodesToScale = self.check(test)
            print(f"Total task: {test}, TotalNodes: {nodesToScale}")
    
    def run_test2(self):
        import random
        for x in range(30):
            num_tasks = random.randint(1,30)
            nodesToScale = self.check(num_tasks)
            print(f"Total task: {num_tasks}, TotalNodes: {nodesToScale}")


max_workers = 3
max_tasks_queued_per_worker = 10


# settings = [
#     {"totalNodes": 1, "tasksMaxLimit": 10, "taskMinLimit": 0},
#     {"totalNodes": 2, "tasksMaxLimit": 20, "taskMinLimit": 10},
#     {"totalNodes": 3, "tasksMaxLimit": 30, "taskMinLimit": 20}
# ]

total_tasks = 24
settings = []

x = autoscalingStrategist(settings)
settings = x.get_settings()
print(json.dumps(settings, indent=4, sort_keys=True))
# nodesToScale = x.check(total_tasks)
# print(f"Total task: {total_tasks}, TotalNodes: {nodesToScale}")
x.run_test1()
# x.run_test2()