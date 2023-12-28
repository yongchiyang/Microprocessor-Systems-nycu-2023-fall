// =============================================================================
//  Program : neuronet.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/06/2023
// -----------------------------------------------------------------------------
//  Description:
//      This is a neural network library that can be used to implement
//  a inferencing model of the classical multilayer perceptorn (MLP) neural
//  network. It reads a model weights file to setup the MLP. The MLP
//  can have up to MAX_LAYERS, which is defined in neuronet.h. To avoid using
//  the C math library, the relu() fucntion is used for the activation
//  function. This degrades the recognition accuracy significantly, but it
//  serves the teaching purposes well.
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

#include "neuronet.h"

int count = 0;
#define DSA_READY_ADDR      0xC4000000
#define DSA_CNT_ADDR        0xC4000004
#define DSA_RESULT_ADDR     0xC4000008
#define DSA_TRIGGER_ADDR    0xC400000C
#define DSA_BUFF_1          0xC4001000
#define DSA_BUFF_2          0xC4002000
volatile unsigned int * p_dsa_ready = (unsigned int *) DSA_READY_ADDR;
volatile unsigned int * p_dsa_cnt = (unsigned int *) DSA_CNT_ADDR;
volatile float * p_dsa_result = (float *) DSA_RESULT_ADDR;
volatile unsigned int * p_dsa_trigger = (unsigned int *) DSA_TRIGGER_ADDR;
volatile float * p_dsa_buff_1 = (float *) DSA_BUFF_1;
volatile float * p_dsa_buff_2 = (float *) DSA_BUFF_2;


void neuronet_init(NeuroNet *nn, int n_layers, int *n_neurons)
{
    count = 0;
    int layer_idx, neuron_idx, sum;
    float *head[MAX_LAYERS];  // Pointer to the first neuron value of each layer.

    if (n_layers < 2 || n_layers > MAX_LAYERS)
    {
        printf("ERROR!!!\n");
        printf("layer count is less than 2 or larger than %d\n", MAX_LAYERS);
        return;
    }

    nn->total_neurons = 0;
    for (layer_idx = 0; layer_idx < n_layers; layer_idx++)
    {
        nn->n_neurons[layer_idx] = n_neurons[layer_idx];
        nn->total_neurons += n_neurons[layer_idx];
    }

    nn->neurons = (float *) malloc(sizeof(float *) * nn->total_neurons);
    nn->forward_weights = (float **) malloc(sizeof(float *) * nn->total_neurons);
    nn->previous_neurons = (float **) malloc(sizeof(float *) * nn->total_neurons);
    nn->total_layers = n_layers;

    neuron_idx = 0;
    for (layer_idx = 0; layer_idx < nn->total_layers; layer_idx++)
    {
        head[layer_idx] = &(nn->neurons[neuron_idx]);
        neuron_idx += nn->n_neurons[layer_idx];
    }

    // Set a shortcut pointer to the output layer neuron values.
    nn->output = head[nn->total_layers - 1];

    // Set the previous layer neuron pointers for each hidden & output neuron
    for (neuron_idx = nn->n_neurons[0], layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        for (unsigned j = 0; j < nn->n_neurons[layer_idx]; ++j, ++neuron_idx)
        {
            nn->previous_neurons[neuron_idx] = head[layer_idx - 1];
        }
    }

    // Initialize the weight array.
    nn->total_weights = 0;
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        // Accumulating # of weights, including one bias value per neuron.
        nn->total_weights += (nn->n_neurons[layer_idx-1] + 1)*nn->n_neurons[layer_idx];
    }
    nn->weights = (float *) malloc(sizeof(float) * nn->total_weights);

    // Set the starting pointer to the forward weights for each neurons.
    sum = 0, neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        for (int idx = 0; idx < nn->n_neurons[layer_idx]; idx++, neuron_idx++)
        {
            nn->forward_weights[neuron_idx] = &(nn->weights[sum]);
            sum += (nn->n_neurons[layer_idx-1] + 1); // add one for bias.
        }
    }
}

void neuronet_load(NeuroNet *nn, float *weights)
{
    for (int idx = 0; idx < nn->total_weights; idx++)
    {
        nn->weights[idx] = *(weights++);
    }
    return;
}

void neuronet_free(NeuroNet *nn)
{
    free(nn->weights);
    free(nn->previous_neurons);
    free(nn->forward_weights);
    free(nn->neurons);
}

int neuronet_eval(NeuroNet *nn, float *images)
{
    float inner_product, max;
    float *p_neuron;
    float *p_weight;
    int idx, layer_idx, neuron_idx, max_idx;

    // Copy the input image array (784 pixels) to the input neurons.
    //memcpy((void *) nn->neurons, (void *) images, nn->n_neurons[0]*sizeof(float));

    // Forward computations - original
    /*
    neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        for (idx = 0; idx < nn->n_neurons[layer_idx]; idx++, neuron_idx++)
        {
            // 'p_weight' points to the first forward weight of a layer.
            p_weight = nn->forward_weights[neuron_idx];
            inner_product = 0.0;

            // Loop over all forward-connected neural links.
            p_neuron = nn->previous_neurons[neuron_idx];
            for (int jdx = 0; jdx < nn->n_neurons[layer_idx-1]; jdx++)
            {
                inner_product += (*p_neuron++) * (*p_weight++);
            }

            inner_product += *(p_weight); // The last weight of a neuron is the bias.
            nn->neurons[neuron_idx] = relu(inner_product);
        }
    }*/

    // Forward computations
    neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {

        p_neuron = nn->previous_neurons[neuron_idx];
        if(layer_idx == 1) dsa_cpy((void *) p_dsa_buff_1, (void *) images, nn->n_neurons[layer_idx-1]);
        else dsa_cpy((void *) p_dsa_buff_1, (void *) p_neuron, nn->n_neurons[layer_idx-1]);
        for (idx = 0; idx < nn->n_neurons[layer_idx]; idx++, neuron_idx++)
        {
            // 'p_weight' points to the first forward weight of a layer.
            p_weight = nn->forward_weights[neuron_idx];            
    
            inner_product = 0.0;
            dsa_cpy((void *) p_dsa_buff_2, (void *) p_weight, nn->n_neurons[layer_idx-1]);
            
            *p_dsa_cnt = nn->n_neurons[layer_idx-1];
            *p_dsa_trigger = 1;
            // memcpy first, while !p_dsa_ready
            while(!(*p_dsa_ready));
            //float dsa_result = (*p_dsa_result);
            inner_product = (*p_dsa_result);
            *p_dsa_ready = 0;

            inner_product += *(p_weight); // The last weight of a neuron is the bias.
            nn->neurons[neuron_idx] = relu(inner_product);
        }
    }

    // Return the index to the maximal neuron value of the output layer.
    max = -1.0, max_idx = 0;
    for (idx = 0; idx < nn->n_neurons[nn->total_layers-1]; idx++)
    {
        if (max < nn->output[idx])
        {
            max_idx = idx;
            max = nn->output[idx];
        }
    }

    return max_idx;
}

float relu(float x)
{
	return x < 0.0 ? 0.0 : x;
}

