// =============================================================================
//  Program : ocr.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/06/2023
// -----------------------------------------------------------------------------
//  Description:
//      This program uses the classical multilayer perceptorn (MLP) neural network
//  for hand-written digits recognition. It reads a model weights file to setup
//  the MLP neural network. The model weights are trained with the famous MNIST
//  dataset. To avoid using the C math library, the relu() fucntion is used for
//  the activation function. This degrades the accuracy significantly, but it
//  serves our purpose well.
//
//  This program is designed as one of the homework projects for the course:
//  Microprocessor Systems: Principles and Implementation
//  Dept. of CS, NYCU (aka NCTU), Hsinchu, Taiwan.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// =============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#define DSA_READY_ADDR      0xC4000000
#define DSA_CNT_ADDR        0xC4000004
#define DSA_RESULT_ADDR     0xC4000008
#define DSA_TRIGGER_ADDR    0xC400000C
#define DSA_BUFF_1          0xC4001000
#define DSA_BUFF_2          0xC4002000
#define DSA_TEST            0xC4004000

volatile unsigned int * p_dsa_ready = (unsigned int *) DSA_READY_ADDR;
volatile unsigned int * p_dsa_cnt = (unsigned int *) DSA_CNT_ADDR;
volatile float * p_dsa_result = (float *) DSA_RESULT_ADDR;
volatile unsigned int * p_dsa_trigger =  (unsigned int *) DSA_TRIGGER_ADDR;
//volatile unsigned int * p_dsa_test = (unsigned int *) DSA_TEST;
volatile float * p_dsa_buff_1 = (float *) DSA_BUFF_1;
volatile float * p_dsa_buff_2 = (float *) DSA_BUFF_2;
int main()
{
    float verctor1[10] = {1.1, 2.2, 3.3, 4.4, 5.5, 6.6, 7.7, 8.8, 9.9, 11.0};
    float weight1[10] =  {2.3, 3.4, 4.5, 5.6, 6.7, 7.8, 8.9, 9.1, 1.2, 2.3};

    float verctor2[10] = {1.3, 2.3, 3.4, 4.5, 5.4, 66.5, 77.3, 88, 99.2, 11.3};
    float weight2[10] =  {6.3, 7.4, 1.5, 2.6, 6.3, 2.8, 78.9, 1.1, 4.2, 5.3};

    float vector3[784];
    float weight3[784];

    for(int i = 0; i < 784; i++)
    {
        vector3[i] = 1.1 * 0.03 * i;
        weight3[i] = 0.045 * i;
    }

    float inner_product = 0.0;
    for(int i = 0; i < 10; i++){
         inner_product += verctor1[i] * weight1[i]; printf("inner = %f\n", inner_product);
    }
    memcpy((void *)p_dsa_buff_1, (void *)verctor1, 10*sizeof(float));
    memcpy((void *)p_dsa_buff_2, (void *)weight1, 10*sizeof(float));
    *p_dsa_cnt = 10;
    *p_dsa_trigger = 1;
    while(!(*p_dsa_ready)) ;
    printf("result = %f, ans = %f\n", *p_dsa_result, inner_product);
    

    inner_product = 0.0;
    for(int i = 0; i < 10; i++) inner_product += verctor2[i] * weight2[i];
    memcpy((void *)p_dsa_buff_1, (void *)verctor2, 10*sizeof(float));
    memcpy((void *)p_dsa_buff_2, (void *)weight2, 10*sizeof(float));
    *p_dsa_ready = 0;
    *p_dsa_cnt = 10;
    *p_dsa_trigger = 1;
    while(!(*p_dsa_ready)) ;
    printf("result = %f, ans = %f\n", *p_dsa_result, inner_product);

    *p_dsa_ready = 0;

    inner_product = 0.0;
    for(int i = 0; i < 784; i++) inner_product += vector3[i] * weight3[i];
    memcpy((void *)p_dsa_buff_1, (void *)vector3, 784*sizeof(float));
    memcpy((void *)p_dsa_buff_2, (void *)weight3, 784*sizeof(float));
    *p_dsa_cnt = 784;
    *p_dsa_trigger = 1;
    while(!(*p_dsa_ready)) ;
    printf("result = %f, ans = %f\n", *p_dsa_result, inner_product);
    return 0;
}

