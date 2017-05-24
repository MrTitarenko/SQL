/*
Подготовка базы данных
1. Выполнить скрипт hr_create.sql с командами создания таблиц БД.
2. Выполнить скрипт hr_popul.sql с командами заполнения таблиц БД.
*/


/*
	Задание 1. Журналирование DML-операций
Разработать механизм журнализации DML-операций, выполн¤емых над таблицей с подразделени¤ми
*/

CREATE TABLE LOG_DEPARTMENTS
  ( user_name         CHAR(32)
  , type_operation    CHAR(32)
  , date_operation    DATE
  , dep_id            NUMBER
  , old_name          CHAR(64)
  , new_name          CHAR(64)
  ) ;
  
CREATE OR REPLACE TRIGGER AUDIT_DEP
	AFTER INSERT OR UPDATE OR DELETE ON departments 
	FOR EACH ROW
DECLARE 
	op_type LOG_DEPARTMENTS.type_operation%TYPE;
	depno departments.department_id%TYPE;
BEGIN
	IF INSERTING THEN op_type := 'INSERT'; END IF;
	IF UPDATING  THEN op_type := 'UPDATE';  END IF;
	IF DELETING  THEN op_type := 'DELETE'; END IF;
	IF INSERTING THEN depno   := :NEW.department_id;
		ELSE 
			depno := :OLD.department_id;
	END IF;
	INSERT INTO LOG_DEPARTMENTS VALUES
		(USER, op_type, SYSDATE, depno, :OLD.department_name, :NEW.department_name);
END;
/

INSERT INTO departments VALUES (26, 'NetCracker', 100, 2600);
UPDATE departments SET department_name = 'OdessaOffice' WHERE department_id = 26;
DELETE FROM departments WHERE department_id = 26;


--	Задание 2. Автоматическая генерация целочисленных значений PK-колонок
-- Задание 2.1
CREATE OR REPLACE TRIGGER empl_id_nextval
	BEFORE INSERT ON employees 
	FOR EACH ROW
BEGIN
	IF :NEW.employee_id IS NULL
		THEN :NEW.employee_id := employee_id.NEXTVAL;
	END IF;
END;
/
CREATE OR REPLACE TRIGGER dep_id_nextval
	BEFORE INSERT ON departments 
	FOR EACH ROW
BEGIN
	IF :NEW.department_id IS NULL
		THEN :NEW.department_id := department_id.NEXTVAL;
	END IF;
END;
/

--	Проверка:
INSERT INTO employees (employee_id, last_name, email, hire_date, job_id, salary, department_id)
    VALUES (null, 'name_1', 'email_1', SYSDATE, 'IT_PROG', 1000, 60);
INSERT INTO departments VALUES (null, 'NetCracker', 100, 2600);

-- Задание 2.2
CREATE OR REPLACE PROCEDURE CREATE_SEQUENCE 
	( table_name IN VARCHAR2,
	 column_name IN VARCHAR2)
AUTHID CURRENT_USER
IS
  max_id NUMBER(20);
BEGIN
  EXECUTE IMMEDIATE
    'SELECT max('||column_name||')
		FROM ' || table_name INTO max_id;
    
  BEGIN
	EXECUTE IMMEDIATE 'DROP SEQUENCE ' || column_name;
    EXCEPTION	WHEN OTHERS THEN
		NULL;
  END;
  
  EXECUTE IMMEDIATE
    'CREATE SEQUENCE ' || column_name || '
     START WITH ' || (max_id+1);
	
  EXECUTE IMMEDIATE
    'CREATE OR REPLACE TRIGGER id_nextval_' || table_name|| '
     BEFORE INSERT ON ' || table_name || '
		FOR EACH ROW
      BEGIN
        IF :NEW.' || column_name || ' IS NULL
          THEN :NEW.' || column_name || ' := ' || column_name || '.NEXTVAL;
        END IF;
      END;';
END;
/

--	Проверка:
BEGIN
	CREATE_SEQUENCE('employees','employee_id');
	CREATE_SEQUENCE('departments','department_id');
END;
/


--	 Задание 3. Обеспечение сложных правил ограничения целостности данных
CREATE TABLE SALARIES
  (	COUNTRY_NAME  VARCHAR2(40)
  , JOB_TITLE     VARCHAR2(35)
  , SALARY_MIN    NUMBER(5)
  , SALARY_MAX	  NUMBER(5)
  ) ;
INSERT INTO SALARIES VALUES ('United States of America', 'Shipping Clerk', 100, 400);
INSERT INTO SALARIES VALUES ('United States of America', 'Programmer', 300, 800);


CREATE OR REPLACE TRIGGER SALARIES_CHECK 
	BEFORE INSERT OR UPDATE ON employees 
	FOR EACH ROW
DECLARE
  job salaries.job_title%TYPE;
	min_tax salaries.salary_min%TYPE;
	max_tax salaries.salary_max%TYPE;
	TAX_OUT_OF_RANGE EXCEPTION;
BEGIN
	SELECT s.job_title, s.salary_min, s.salary_max INTO job, min_tax, max_tax 
    FROM salaries s
      JOIN jobs j ON j.job_id = :NEW.job_id
      JOIN departments d  ON d.department_id = :NEW.department_id
      JOIN locations l    ON l.location_id = d.location_id
      JOIN countries c    ON c.country_id = l.country_id
    WHERE s.job_title = j.job_title
      AND s.country_name = c.country_name;
      
	IF (:NEW.salary < min_tax OR :NEW.salary > max_tax) 
    THEN RAISE TAX_OUT_OF_RANGE;
	END IF;
EXCEPTION
	WHEN TAX_OUT_OF_RANGE THEN
		RAISE_APPLICATION_ERROR(-20500,
    'Оклад ' || TO_CHAR(:NEW.salary) || 
    ' вне диапазона для должности ' || JOB ||
    ' для служащего ' || :NEW.last_name);

	WHEN NO_DATA_FOUND THEN
		RAISE_APPLICATION_ERROR(-20550, 
			'Неверная должность id=' || :NEW.job_id);
END;
/

--	Проверка:
INSERT INTO employees (employee_id, last_name, email, hire_date, job_id, salary, department_id)
    VALUES (300, 'name_1', 'email_1', TO_DATE('01-01-2000', 'dd-mm-yyyy'), 'IT_PROG', 1000, 60);


--	Задание 4. Материализация представлений (виртуальных таблиц)
DECLARE
  CURSOR tab IS
    SELECT e.department_id AS d_id, MAX(e.salary) AS max_s
      FROM employees e 
        JOIN departments d ON e.department_id = d.department_id
      GROUP BY e.department_id
      ORDER BY e.department_id;
BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE MAX_DEPART_SALARY
                      (dep_id NUMBER(4) PRIMARY KEY,
                       max_salary NUMBER(8,2))';
	FOR rec IN tab LOOP
		EXECUTE IMMEDIATE 'INSERT INTO MAX_DEPART_SALARY VALUES
                     (' || rec.d_id || ', ' || rec.max_s || ')';
    END LOOP;
END;
/

CREATE OR REPLACE TRIGGER max_salary_trigger
	AFTER INSERT OR UPDATE OR DELETE ON employees 
	FOR EACH ROW
DECLARE 
	max_dep_sal employees.salary%TYPE;
	new_max_sal employees.salary%TYPE;
BEGIN
  SELECT max_salary INTO max_dep_sal
    FROM max_depart_salary
    WHERE dep_id = :NEW.department_id;
  SELECT MAX(salary) INTO new_max_sal
    FROM employees
    WHERE department_id = :NEW.department_id;

	IF INSERTING OR UPDATING
    THEN
      IF max_dep_sal < :NEW.salary
        THEN
          UPDATE max_depart_salary
            SET max_salary = :NEW.salary
            WHERE dep_id = :NEW.department_id;
      END IF;
		ELSE
      IF max_dep_sal = :OLD.salary
        THEN
          UPDATE max_depart_salary
            SET max_salary = new_max_sal
            WHERE dep_id = :NEW.department_id;
      END IF;
	END IF;
END;
/


--	Задание 5. Автоматическая генерация строковых значений PK-колонок
CREATE OR REPLACE FUNCTION GET_JOB_ID 
	(job_title IN VARCHAR2)
RETURN VARCHAR2
IS
	j_id jobs.job_id%TYPE;
	space_no  NUMBER(2);
	slct      NUMBER(2);
BEGIN
  space_no := INSTR(job_title, ' ', 1);
  IF space_no > 1 THEN
    j_id := SUBSTR(job_title, 1, 1) || '_' || SUBSTR(job_title, space_no+1, 1);
  ELSE
    j_id := SUBSTR(job_title, 1, 2);
  END IF;
  
  LOOP
  SELECT 1 INTO slct
    FROM JOBS
      WHERE job_id = j_id;
  IF SQL%FOUND then
    j_id := j_id || 1;
  END IF;
  END LOOP;
  
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
  RETURN j_id;
END;
/

CREATE OR REPLACE TRIGGER job_id_generation
	BEFORE INSERT OR UPDATE ON jobs 
	FOR EACH ROW
DECLARE 
	j_id jobs.job_id%TYPE;
BEGIN
  j_id := get_job_id(:NEW.job_title);
	IF :NEW.job_id IS NULL
		THEN :NEW.job_id := j_id;
	END IF;
END;
/

INSERT INTO jobs VALUES (null, 'Stock Manager', 5555, 8888);
UPDATE jobs SET MIN_SALARY = 1000 WHERE JOB_ID = 'S_M';


--	Задание 6. Генерация PL/SQL-кода журналирующих триггеров
CREATE OR REPLACE FUNCTION GENERATE_LOGGING 
	(tab_name IN VARCHAR2)
RETURN VARCHAR2
IS
  CURSOR c1 IS
    SELECT COLUMN_NAME
      FROM USER_TAB_COLUMNS
      WHERE TABLE_NAME = UPPER(tab_name);
  c1_id c1%ROWTYPE;
  c1_name c1%ROWTYPE;
BEGIN
  OPEN c1;
  FETCH c1 INTO c1_id;
  FETCH c1 INTO c1_name;
  
  EXECUTE IMMEDIATE
  'CREATE TABLE LOG_' || tab_name || '
  ( user_name         CHAR(32)
  , type_operation    CHAR(32)
  , date_operation    DATE
  , dep_id            NUMBER
  , old_name          CHAR(64)
  , new_name          CHAR(64)
  )';
  
  EXECUTE IMMEDIATE
   'CREATE OR REPLACE TRIGGER AUDIT_' || tab_name || '
    AFTER INSERT OR UPDATE OR DELETE ON ' || tab_name || '
    FOR EACH ROW
  DECLARE 
    op_type LOG_' || tab_name || '.type_operation%TYPE;
    depno ' || tab_name || '.' || c1_id || '%TYPE;
  BEGIN
    IF INSERTING THEN op_type := ''INSERT''; END IF;
    IF UPDATING  THEN op_type := ''UPDATE'';  END IF;
    IF DELETING  THEN op_type := ''DELETE''; END IF;
    IF INSERTING THEN depno   := :NEW.' || c1_id || ';
      ELSE 
        depno := :OLD.' || c1_id || ';
    END IF;
    INSERT INTO LOG_' || tab_name || ' VALUES
      (USER, op_type, SYSDATE, depno, :OLD.' || c1_name || ', :NEW.' || c1_name || ');
  END;';

	RETURN dbms_metadata.get_ddl('TRIGGER', 'AUDIT_' || tab_name);
END;
/

SHOW ERRORS;