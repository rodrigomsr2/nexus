package br.com.rodrigomsr2.nexusargocd.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ProbeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("GET /api/ok deve retornar 200 com body válido")
    void ok_returns200() throws Exception {
        mockMvc.perform(get("/api/ok"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    @DisplayName("GET /api/redirect deve retornar 302 com header Location")
    void redirect_returns302() throws Exception {
        mockMvc.perform(get("/api/redirect"))
                .andExpect(status().isFound())
                .andExpect(result ->
                        result.getResponse().getHeader("Location").contains("/api/ok"));
    }

    @Test
    @DisplayName("GET /api/not-found deve retornar 404 com body válido")
    void notFound_returns404() throws Exception {
        mockMvc.perform(get("/api/not-found"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value("not_found"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    @DisplayName("GET /api/error deve retornar 500 com body válido")
    void error_returns500() throws Exception {
        mockMvc.perform(get("/api/error"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.status").value("internal_server_error"))
                .andExpect(jsonPath("$.timestamp").exists());
    }
}
