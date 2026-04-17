//
// Created by Reed Sloan on 4/16/26.
//

#include "lve_model.hpp"

// std
#include <cassert>

namespace lve {
    std::vector<VkVertexInputBindingDescription> LveModel::Vertex::getBindingDescriptions() {
        return {
            {0, sizeof(Vertex), VK_VERTEX_INPUT_RATE_VERTEX}
        };
    }

    std::vector<VkVertexInputAttributeDescription> LveModel::Vertex::getAttributeDescriptions() {
        return {
            {0, 0, VK_FORMAT_R32G32_SFLOAT, offsetof(Vertex, position)}, // position attr
            {1, 0, VK_FORMAT_R32G32B32_SFLOAT, offsetof(Vertex, color)} // color attr
        };
    }

    LveModel::LveModel(LveDevice &device, const std::vector<Vertex> &vertices) : lveDevice(device) {
        createVertexBuffers(vertices);
    }

    LveModel::~LveModel() {
        vkDestroyBuffer(lveDevice.device(), vertexBuffer, nullptr);
        vkFreeMemory(lveDevice.device(), vertexBufferMemory, nullptr);
    }

    void LveModel::bind(VkCommandBuffer commandBuffer) {
        VkBuffer buffers[] = {vertexBuffer};
        VkDeviceSize offsets[] = {0};
        vkCmdBindVertexBuffers(commandBuffer, 0, 1, buffers, offsets);
    }

    void LveModel::draw(VkCommandBuffer commandBuffer) {
        vkCmdDraw(commandBuffer, vertexCount, 1, 0, 0);
    }

    void LveModel::createVertexBuffers(const std::vector<Vertex> &vertices) {
        vertexCount = static_cast<uint32_t>(vertices.size());
        assert(vertexCount >= 3 && "Vertex count must be greater than 3");
        VkDeviceSize bufferSize = sizeof(vertices[0]) * vertexCount;
        lveDevice.createBuffer(
            bufferSize,
            VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            vertexBuffer,
            vertexBufferMemory
        );

        void *data;
        vkMapMemory(lveDevice.device(), vertexBufferMemory, 0, bufferSize, 0, &data);
        memcpy(data, vertices.data(), static_cast<size_t>(bufferSize));
        vkUnmapMemory(lveDevice.device(), vertexBufferMemory);
    }
} // namespace lve
