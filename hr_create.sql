DROP TABLE regions     CASCADE CONSTRAINTS;
DROP TABLE departments CASCADE CONSTRAINTS;
DROP TABLE locations   CASCADE CONSTRAINTS;
DROP TABLE jobs        CASCADE CONSTRAINTS;
DROP TABLE job_history CASCADE CONSTRAINTS;
DROP TABLE employees   CASCADE CONSTRAINTS;
DROP TABLE countries   CASCADE CONSTRAINTS;  

CREATE TABLE regions
    ( region_id    NUMBER NOT NULL PRIMARY KEY,
	region_name    VARCHAR2(25)
    );

CREATE TABLE countries 
    ( country_id      CHAR(2) NOT NULL PRIMARY KEY,
    country_name    VARCHAR2(40), 
    region_id       NUMBER REFERENCES regions(region_id)
    );

CREATE TABLE locations
    ( location_id    NUMBER(4) PRIMARY KEY,
    street_address VARCHAR2(40),
    postal_code    VARCHAR2(12),
    city       VARCHAR2(30) NOT NULL,
    state_province VARCHAR2(25),
    country_id     CHAR(2) REFERENCES countries(country_id) 
    ) ;

CREATE TABLE departments
    ( department_id    NUMBER(4) PRIMARY KEY,
	department_name  VARCHAR2(30) NOT NULL,
	manager_id       NUMBER(6),
	location_id      NUMBER(4) REFERENCES locations (location_id)
    ) ;

CREATE TABLE jobs
    ( job_id         VARCHAR2(10) 	PRIMARY KEY,
    job_title      VARCHAR2(35) NOT NULL,
    min_salary     NUMBER(6),
    max_salary     NUMBER(6)
    ) ;

CREATE TABLE employees
    ( employee_id    NUMBER(6),
    first_name     VARCHAR2(20),
    last_name      VARCHAR2(25) NOT NULL,
    email          VARCHAR2(25) NOT NULL,
    phone_number   VARCHAR2(20),
    hire_date      DATE NOT NULL,
    job_id         VARCHAR2(10) NOT NULL,
    salary         NUMBER(8,2),
    commission_pct NUMBER(2,2),
    manager_id     NUMBER(6),
    department_id  NUMBER(4),
    CHECK (salary > 0),
    UNIQUE (email),
	PRIMARY KEY (employee_id),
	FOREIGN KEY (department_id)
                      REFERENCES departments,
	FOREIGN KEY (job_id)
                      REFERENCES jobs (job_id),
	FOREIGN KEY (manager_id)
                      REFERENCES employees				  
    ) ;

	
CREATE TABLE job_history
    ( employee_id   NUMBER(6) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
	job_id        VARCHAR2(10) NOT NULL REFERENCES jobs, 
	department_id NUMBER(4) REFERENCES departments,
    CHECK (end_date > start_date),
	PRIMARY KEY (employee_id, start_date),
    FOREIGN KEY (employee_id) REFERENCES employees
	);

COMMIT;
