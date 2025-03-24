package com.devsecops;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@Profile("test")
public class TestSecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/**") // همه مسیرها رو شامل می‌شه
            .authorizeHttpRequests(authorize -> authorize
                .anyRequest().permitAll() // همه درخواست‌ها آزاد باشن
            )
            .csrf().disable(); // CSRF رو غیرفعال کن
        return http.build();
    }
}