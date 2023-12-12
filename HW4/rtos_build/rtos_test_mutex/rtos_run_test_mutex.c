// =============================================================================
//  Program : rtos_run.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/11/2021
// -----------------------------------------------------------------------------
//  Description:
//  This is a multi-thread program to demo the usage of FreeRTOS and shared
//  resource protection using a mutex.
//
//  This program is designed as one of the homework project for the course:
//  Microprocessor Systems: Principles and Implementation
//  Dept. of CS, NYCU (aka NCTU), Hsinchu, Taiwan.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Nov/14/2023, by Chun-Jen Tsai:
//    Add a random number generating task to the second thread to balance
//    the load.
// =============================================================================

/* Standard includes. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* FreeRTOS includes. */
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

void vApplicationMallocFailedHook(void);
void vApplicationIdleHook(void);
void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName);
void vApplicationTickHook(void);

void TaskA_Handler(void *pvParameters); // highest priority
void TaskB_Handler(void *pvParameters); // middle priority
void TaskC_Handler(void *pvParameters);
void TaskD_Handler(void *pvParameters);
TaskHandle_t xHandleA;
TaskHandle_t xHandleB;
TaskHandle_t xHandleC;
TaskHandle_t xHandleD;
xSemaphoreHandle xMutex1; // a mutex used to protect shared variable.
xSemaphoreHandle xMutex2; // a mutex used to protect shared variable.

int main(void)
{
    xMutex1 = xSemaphoreCreateMutex();
    if (xMutex1 == NULL) return 1;
    xMutex2 = xSemaphoreCreateMutex();
    if (xMutex2 == NULL) return 1;

    xTaskCreate(TaskA_Handler, "Task1", 256, NULL, 3, &xHandleA);
    xTaskCreate(TaskB_Handler, "Task2", 256, NULL, 5, &xHandleB);
    xTaskCreate(TaskC_Handler, "Task3", 256, NULL, 2, &xHandleC);
    xTaskCreate(TaskD_Handler, "Task4", 256, NULL, 4, &xHandleD);
    vTaskStartScheduler();
    return 0;
}


void TaskA_Handler(void *pvParameters)
{
    // base priority 3
    vTaskDelay(2);
    xSemaphoreTake(xMutex2, portMAX_DELAY);

    printf("this is task A, get mutex2\n");

    

    /* The thread has ended, we must delete this task from the task queue. */
    vTaskDelete(NULL);
}

void TaskB_Handler(void *pvParameters)
{
    //vTaskDelay(1);
    vTaskDelay(3);
    xSemaphoreTake(xMutex1, portMAX_DELAY);
    printf("this is task B, get mutex1\n");

    vTaskDelete(NULL);
}

void TaskC_Handler(void *pvParameters)
{
    // basepriority = 2
    xSemaphoreTake(xMutex1, portMAX_DELAY);
    printf("this is task C, take mutex1\n");
    xSemaphoreTake(xMutex2, portMAX_DELAY);
    printf("this is task C, take mutex2\n");

    vTaskDelete(NULL);
}

void TaskD_Handler(void *pvParameters)
{
    //vTaskDelay(1);
    xSemaphoreTake(xMutex2, portMAX_DELAY);
    printf("this is task D, get mutex2\n");
    vTaskDelay(5);
    int taskA_p = uxTaskPriorityGet(xHandleA);
    int taskB_p = uxTaskPriorityGet(xHandleB);
    int taskC_p = uxTaskPriorityGet(xHandleC);
    int taskD_p = uxTaskPriorityGet(xHandleD);

    printf("taskA's priority = %d\n", taskA_p);
    printf("taskB's priority = %d\n", taskB_p);
    printf("taskC's priority = %d\n", taskC_p);
    printf("taskD's priority = %d\n", taskD_p);
    vTaskDelay(5);
    xSemaphoreGive(xMutex2);

    /* The thread has ended, we must delete this task from the task queue. */
    vTaskDelete(NULL);
}
void vApplicationMallocFailedHook(void)
{
    /* vApplicationMallocFailedHook() will only be called if
       configUSE_MALLOC_FAILED_HOOK is set to 1 in FreeRTOSConfig.h.  It is a hook
       function that will get called if a call to pvPortMalloc() fails.
       pvPortMalloc() is called internally by the kernel whenever a task, queue,
       timer or semaphore is created.  It is also called by various parts of the
       demo application.  If heap_1.c or heap_2.c are used, then the size of the
       heap available to pvPortMalloc() is defined by configTOTAL_HEAP_SIZE in
       FreeRTOSConfig.h, and the xPortGetFreeHeapSize() API function can be used
       to query the size of free heap space that remains (although it does not
       provide information on how the remaining heap might be fragmented). */
    taskDISABLE_INTERRUPTS();
    for (;;);
}

void vApplicationIdleHook(void)
{
    /* vApplicationIdleHook() will only be called if configUSE_IDLE_HOOK is set
       to 1 in FreeRTOSConfig.h.  It will be called on each iteration of the idle
       task.  It is essential that code added to this hook function never attempts
       to block in any way (for example, call xQueueReceive() with a block time
       specified, or call vTaskDelay()).  If the application makes use of the
       vTaskDelete() API function (as this demo application does) then it is also
       important that vApplicationIdleHook() is permitted to return to its calling
       function, because it is the responsibility of the idle task to clean up
       memory allocated by the kernel to any task that has since been deleted. */
}

void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName)
{
    (void) pcTaskName;
    (void) pxTask;

    /* Run time stack overflow checking is performed if
       configCHECK_FOR_STACK_OVERFLOW is defined to 1 or 2.  This hook
       function is called if a stack overflow is detected. */
    taskDISABLE_INTERRUPTS();
    printf("Stack overflow error.\n");
    for (;;);
}

void vApplicationTickHook(void)
{
    /* vApplicationTickHook */
}

void vAssertCalled(void)
{
    taskDISABLE_INTERRUPTS();
    while (1)
    {
        __asm volatile ("NOP");
    }
}

void vExternalISR( uint32_t cause )
{
}

