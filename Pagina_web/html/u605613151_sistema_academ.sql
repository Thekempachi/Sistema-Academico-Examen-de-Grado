-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Sep 02, 2025 at 02:15 PM
-- Server version: 10.11.10-MariaDB-log
-- PHP Version: 7.2.34

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `u605613151_sistema_academ`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Asistencia_Insertar` (IN `p_nro_registro` VARCHAR(30), IN `p_id_oferta_materia` BIGINT UNSIGNED, IN `p_fecha` DATE, IN `p_observacion` VARCHAR(200), OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_id_estudiante BIGINT UNSIGNED;
  DECLARE v_not_found     TINYINT DEFAULT 0;
  DECLARE v_dummy         BIGINT UNSIGNED;


  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;


  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;


  IF p_fecha IS NULL THEN
    SET p_status = 'FECHA_INVALIDA'; LEAVE proc;
  END IF;


  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;


  SET v_not_found = 0;
  SELECT id_Estudiante
    INTO v_id_estudiante
    FROM estudiante
   WHERE nro_registro = TRIM(p_nro_registro)
   FOR UPDATE;
  IF v_not_found = 1 THEN
    ROLLBACK; SET p_status = 'ESTUDIANTE_NO_ENCONTRADO'; LEAVE proc;
  END IF;


  SET v_not_found = 0;
  SELECT id_Oferta_Materia
    INTO v_dummy
    FROM oferta_materia
   WHERE id_Oferta_Materia = p_id_oferta_materia
   FOR UPDATE;
  IF v_not_found = 1 THEN
    ROLLBACK; SET p_status = 'OFERTA_NO_ENCONTRADA'
; LEAVE proc;
  END IF;

  INSERT INTO asistencia (id_Estudiante, id_Oferta_Materia, fecha, observacion)
  VALUES (v_id_estudiante, p_id_oferta_materia, p_fecha, p_observacion);

  COMMIT;
  SET p_status = 'ok';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Carrera_Insertar` (IN `p_codigo` VARCHAR(30), IN `p_nombre` VARCHAR(200), IN `p_fecha_creacion` DATE, IN `p_codigo_facultad` VARCHAR(30), IN `p_ci_jefe` VARCHAR(20), OUT `p_id_carrera` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_not_found   TINYINT DEFAULT 0;
  DECLARE v_dummy       BIGINT  UNSIGNED;
  DECLARE v_id_facultad BIGINT  UNSIGNED;
  DECLARE v_id_usuario  BIGINT  UNSIGNED;

  DECLARE EXIT HANDLER FOR 1062
  BEGIN
    ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'CODIGO_DUPLICADO';
  END;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'ERROR_SQL';
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  /* 1) Resolver FACULTAD por CODIGO y bloquearla */
  SET v_not_found = 0;
  SELECT id_Facultad
    INTO v_id_facultad
    FROM facultad
   WHERE codigo = p_codigo_facultad
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'FACULTAD_NO_ENCONTRADA_POR_CODIGO'; LEAVE proc;
  END IF;

  IF p_ci_jefe IS NOT NULL THEN
    /* 2.a) Obtener id_Usuario por CI (Persona↔Usuario) */
    SET v_not_found = 0;
    SELECT u.id_Usuario
      INTO v_id_usuario
      FROM usuario u
      JOIN persona p ON p.id_Persona = u.id_Usuario
     WHERE p.ci = p_ci_jefe
     FOR UPDATE;

    IF v_not_found = 1 THEN
      ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'USUARIO_NO_ENCONTRADO_POR_CI'; LEAVE proc;
    END IF;

    /* 2.b) Verificar que tenga rol JEFE_CARRERA */
    SET v_not_found = 0;
    SELECT 1 INTO v_dummy
      FROM usuario_rol ur
      JOIN rol r ON r.id_Rol = ur.id_Rol
     WHERE ur.id_Usuario = v_id_usuario
       AND r.nombre = 'JEFE_CARRERA'
     FOR UPDATE;

    IF v_not_found = 1 THEN
      ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'USUARIO_SIN_ROL_JEFE_CARRERA'; LEAVE proc;
    END IF;
  ELSE
    SET v_id_usuario = NULL;  
  END IF;

  /* 3) Evitar codigo duplicado explícitamente y bloquear si existiera */
  SET v_not_found = 0;
  SELECT id_Carrera INTO v_dummy
    FROM carrera
   WHERE codigo = p_codigo
   FOR UPDATE;

  IF v_not_found = 0 THEN
    ROLLBACK; SET p_id_carrera = NULL; SET p_status = 'CODIGO_DUPLICADO'; LEAVE proc;
  END IF;

  INSERT INTO carrera (codigo, nombre, fecha_creacion, id_Facultad, id_usuario)
  VALUES (p_codigo, p_nombre, p_fecha_creacion, v_id_facultad, v_id_usuario);

  SET p_id_carrera = LAST_INSERT_ID();
  COMMIT;
  SET p_status = 'ok';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Contar_Carrera` (IN `p_id_carrera` BIGINT UNSIGNED)   proc:BEGIN
  DECLARE v_not_found TINYINT DEFAULT 0;
  DECLARE v_dummy     BIGINT UNSIGNED;
  DECLARE v_total     INT UNSIGNED;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = 1;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT id_Carrera
    INTO v_dummy
    FROM carrera
   WHERE id_Carrera = p_id_carrera
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK;
    SELECT NULL AS total;
    LEAVE proc;
  END IF;

  SET v_total = fn_CantidadEstudiantesCarrera(p_id_carrera);

  COMMIT;
  SELECT v_total AS total;
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Correcion_Nota` (IN `p_id_nota_parcial` BIGINT UNSIGNED, IN `p_valor_nuevo` DECIMAL(5,2), IN `p_motivo` VARCHAR(200), OUT `p_id_correcion` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
    DECLARE v_valor_anterior DECIMAL(5,2);
    DECLARE v_ts_bo          TIMESTAMP;
    DECLARE v_not_found      TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_not_found = 1;
    END;

    SET v_ts_bo = CONVERT_TZ(UTC_TIMESTAMP(), '+00:00','-04:00');

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

        SET v_not_found = 0;
        SELECT valor
          INTO v_valor_anterior
          FROM nota_parcial
         WHERE id_Nota_Parcial = p_id_nota_parcial
         FOR UPDATE;

        IF v_not_found = 1 THEN
            ROLLBACK; SET p_id_correcion = NULL; SET p_status = 'NOTA_NO_ENCONTRADA'; LEAVE proc;
        END IF;

        INSERT INTO correcion_nota (valor_anterior, valor_nuevo, fecha_correcion, motivo, id_Nota_Parcial)
        VALUES (v_valor_anterior, p_valor_nuevo, v_ts_bo, p_motivo, p_id_nota_parcial);

        SET p_id_correcion = LAST_INSERT_ID();

    COMMIT;

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

        UPDATE nota_parcial
           SET valor = p_valor_nuevo
         WHERE id_Nota_Parcial = p_id_nota_parcial
           AND valor            = v_valor_anterior;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK; SET p_status = 'VALOR_CAMBIADO_CONCURRENTE'; LEAVE proc;
        END IF;

    COMMIT;
    SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Docente_Insertar` (IN `p_ci` VARCHAR(20), IN `p_fecha_contratacion` DATE, IN `p_estado` VARCHAR(20), IN `p_certificacion` VARCHAR(200), OUT `p_id_docente` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_not_found  TINYINT DEFAULT 0;
  DECLARE v_tmp        BIGINT  UNSIGNED;
  DECLARE v_id_usuario BIGINT  UNSIGNED;
  DECLARE v_estado     ENUM('ACTIVO','INACTIVO');

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;   
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  IF p_fecha_contratacion IS NULL THEN
    SET p_id_docente = NULL; SET p_status = 'FECHA_INVALIDA'; LEAVE proc;
  END IF;

  SET v_estado = CASE UPPER(COALESCE(p_estado,'ACTIVO'))
                   WHEN 'ACTIVO'   THEN 'ACTIVO'
                   WHEN 'INACTIVO' THEN 'INACTIVO'
                   ELSE 'ACTIVO'
                 END;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT u.id_Usuario
    INTO v_id_usuario
    FROM usuario u
    JOIN persona p ON p.id_Persona = u.id_Usuario
   WHERE p.ci = p_ci
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK; SET p_id_docente = NULL; SET p_status = 'USUARIO_NO_ENCONTRADO_POR_CI'; LEAVE proc;
  END IF;

  SET v_not_found = 0;
  SELECT id_Docente INTO v_tmp
    FROM docente
   WHERE id_Docente = v_id_usuario
   FOR UPDATE;

  IF v_not_found = 0 THEN
    IF EXISTS (
        SELECT 1
          FROM docente
         WHERE id_Docente = v_id_usuario
           AND (fecha_contratacion <> p_fecha_contratacion
                OR estado             <> v_estado
                OR COALESCE(certificacion,'') <> COALESCE(p_certificacion,''))
    ) THEN
      UPDATE docente
         SET fecha_contratacion = p_fecha_contratacion,
             estado             = v_estado,
             certificacion      = p_certificacion
       WHERE id_Docente = v_id_usuario;

      COMMIT; SET p_id_docente = v_id_usuario; SET p_status = 'ACTUALIZADO'; LEAVE proc;
    ELSE
      COMMIT; SET p_id_docente = v_id_usuario; SET p_status = 'YA_EXISTE'; LEAVE proc;
    END IF;
  END IF;

  INSERT INTO docente (id_Docente, fecha_contratacion, estado, certificacion)
  VALUES (v_id_usuario, p_fecha_contratacion, v_estado, p_certificacion);

  SET p_id_docente = v_id_usuario;
  COMMIT; 
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Estudiante_Insertar` (IN `p_ci` VARCHAR(20), IN `p_nro_registro` VARCHAR(30), IN `p_estado` VARCHAR(20), OUT `p_id_estudiante` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_not_found   TINYINT DEFAULT 0;
  DECLARE v_tmp         BIGINT  UNSIGNED;
  DECLARE v_id_usuario  BIGINT  UNSIGNED;
  DECLARE v_estado      ENUM('REGULAR','BAJA','SUSPENDIDO');

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET v_estado = CASE UPPER(IFNULL(p_estado,'REGULAR'))
                   WHEN 'REGULAR'   THEN 'REGULAR'
                   WHEN 'BAJA'      THEN 'BAJA'
                   WHEN 'SUSPENDIDO'THEN 'SUSPENDIDO'
                   ELSE 'REGULAR'
                 END;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT u.id_Usuario
    INTO v_id_usuario
    FROM usuario u
    JOIN persona p ON p.id_Persona = u.id_Usuario
   WHERE p.ci = p_ci
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK; SET p_id_estudiante = NULL; SET p_status = 'USUARIO_NO_ENCONTRADO_POR_CI'; LEAVE proc;
  END IF;

  SET v_not_found = 0;
  SELECT id_Estudiante
    INTO v_tmp
    FROM estudiante
   WHERE nro_registro = p_nro_registro
   FOR UPDATE;

  IF v_not_found = 0 AND v_tmp <> v_id_usuario THEN
    ROLLBACK; SET p_id_estudiante = NULL; SET p_status = 'NRO_REGISTRO_DUPLICADO'; LEAVE proc;
  END IF;

  SET v_not_found = 0;
  SELECT id_Estudiante
    INTO v_tmp
    FROM estudiante
   WHERE id_Estudiante = v_id_usuario
   FOR UPDATE;

  IF v_not_found = 0 THEN
    IF EXISTS (SELECT 1
                 FROM estudiante
                WHERE id_Estudiante = v_id_usuario
                  AND (nro_registro <> p_nro_registro OR estado <> v_estado)) THEN

      UPDATE estudiante
         SET nro_registro = p_nro_registro,
             estado       = v_estado
       WHERE id_Estudiante = v_id_usuario;

      COMMIT; SET p_id_estudiante = v_id_usuario; SET p_status = 'ACTUALIZADO'; LEAVE proc;

    ELSE
      COMMIT; SET p_id_estudiante = v_id_usuario; SET p_status = 'YA_EXISTE'; LEAVE proc;
    END IF;
  END IF;

  INSERT INTO estudiante (id_Estudiante, nro_registro, estado)
  VALUES (v_id_usuario, p_nro_registro, v_estado);

  SET p_id_estudiante = v_id_usuario;
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Materia_Insertar` (IN `p_codigo` VARCHAR(30), IN `p_sigla` VARCHAR(20), OUT `p_id_materia` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_codigo VARCHAR(30);
  DECLARE v_sigla  VARCHAR(20);
  DECLARE v_dummy  BIGINT UNSIGNED;
  DECLARE v_nf     TINYINT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;


  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_nf = 1;
  END;

  SET v_codigo = TRIM(p_codigo);
  SET v_sigla  = UPPER(TRIM(p_sigla));

  IF v_codigo IS NULL OR v_codigo = '' OR v_sigla IS NULL OR v_sigla = '' THEN
    SET p_id_materia = NULL; 
    SET p_status     = 'PARAMETROS_INVALIDOS';
    LEAVE proc;
  END IF;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_nf = 0;
  SELECT id_Materia INTO v_dummy
    FROM materia
   WHERE codigo = v_codigo
   FOR UPDATE;
  IF v_nf = 0 THEN
    ROLLBACK; 
    SET p_id_materia = NULL; 
    SET p_status     = 'CODIGO_DUPLICADO';
    LEAVE proc;
  END IF;

  SET v_nf = 0;
  SELECT id_Materia INTO v_dummy
    FROM materia
   WHERE sigla = v_sigla
   FOR UPDATE;
  IF v_nf = 0 THEN
    ROLLBACK; 
    SET p_id_materia = NULL; 
    SET p_status     = 'SIGLA_DUPLICADA';
    LEAVE proc;
  END IF;

  INSERT INTO materia (codigo, sigla)
  VALUES (v_codigo, v_sigla);

  SET p_id_materia = LAST_INSERT_ID();
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `NotaParcial_Insertar` (IN `p_nro_registro` VARCHAR(30), IN `p_id_docente` BIGINT UNSIGNED, IN `p_id_oferta` BIGINT UNSIGNED, IN `p_tipo` VARCHAR(20), IN `p_valor` DECIMAL(5,2), IN `p_observacion` VARCHAR(200), OUT `p_id_nota` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
    DECLARE v_not_found     TINYINT DEFAULT 0;
    DECLARE v_id_estudiante BIGINT  UNSIGNED;
    DECLARE v_dummy         INT;
    DECLARE v_tipo          ENUM('EXAMEN','PRACTICA','TAREA','PROYECTO','OTRO');
    DECLARE v_fecha_bo      DATE;

    /* Handler general */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_not_found = 1;
    END;

    /* Normalizar tipo */
    SET v_tipo = CASE UPPER(COALESCE(p_tipo,'OTRO'))
                   WHEN 'EXAMEN'   THEN 'EXAMEN'
                   WHEN 'PRACTICA' THEN 'PRACTICA'
                   WHEN 'TAREA'    THEN 'TAREA'
                   WHEN 'PROYECTO' THEN 'PROYECTO'
                   ELSE 'OTRO'
                 END;

    SET v_fecha_bo = DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00','-04:00'));

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

        SET v_not_found = 0;
        SELECT id_Estudiante
          INTO v_id_estudiante
          FROM estudiante
         WHERE nro_registro = p_nro_registro
         FOR UPDATE;
        IF v_not_found = 1 THEN
            ROLLBACK; SET p_id_nota = NULL; SET p_status = 'ESTUDIANTE_NO_ENCONTRADO'; LEAVE proc;
        END IF;

        SET v_not_found = 0;
        SELECT 1 INTO v_dummy
          FROM docente
         WHERE id_Docente = p_id_docente
         FOR UPDATE;
        IF v_not_found = 1 THEN
            ROLLBACK; SET p_id_nota = NULL; SET p_status = 'DOCENTE_NO_ENCONTRADO'; LEAVE proc;
        END IF;

        SET v_not_found = 0;
        SELECT 1 INTO v_dummy
          FROM oferta_materia
         WHERE id_Oferta_Materia = p_id_oferta
         FOR UPDATE;
        IF v_not_found = 1 THEN
            ROLLBACK; SET p_id_nota = NULL; SET p_status = 'OFERTA_NO_ENCONTRADA'; LEAVE proc;
        END IF;

        /* 4) INSERT: ahora sí incluye id_Oferta_Materia */
        INSERT INTO nota_parcial (tipo, valor, fecha, observacion, id_Docente, id_Estudiante, id_Oferta_Materia)
        VALUES (v_tipo, p_valor, v_fecha_bo, p_observacion, p_id_docente, v_id_estudiante, p_id_oferta);

        SET p_id_nota = LAST_INSERT_ID();

    COMMIT;
    SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Pensum_Insertar` (IN `p_nro_plan` VARCHAR(30), IN `p_codigo_materia` VARCHAR(30), IN `p_estado` VARCHAR(10), OUT `p_status` VARCHAR(32))   BEGIN
  DECLARE v_not_found TINYINT DEFAULT 0;
  DECLARE v_dummy BIGINT UNSIGNED;
  DECLARE v_estado ENUM('ACTIVO','INACTIVO');
  DECLARE v_abort  TINYINT DEFAULT 0;
  DECLARE v_msg    VARCHAR(32) DEFAULT '';

  DECLARE v_id_plan_estudio BIGINT UNSIGNED;
  DECLARE v_id_materia      BIGINT UNSIGNED;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR 1062
  BEGIN
    ROLLBACK;
    SET v_abort = 1;
    SET v_msg   = 'YA_EXISTE';
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET v_estado = CASE UPPER(COALESCE(p_estado,'ACTIVO'))
                   WHEN 'ACTIVO'   THEN 'ACTIVO'
                   WHEN 'INACTIVO' THEN 'INACTIVO'
                   ELSE 'ACTIVO'
                 END;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  /* 1) Resolver plan por nro_Plan */
  SET v_not_found = 0;
  SELECT id_Plan_Estudio
    INTO v_id_plan_estudio
    FROM plan_estudio
   WHERE nro_Plan = p_nro_plan
   FOR UPDATE;
  IF v_not_found = 1 THEN
    ROLLBACK; SET v_abort=1; SET v_msg='PLAN_NO_ENCONTRADO';
  END IF;

  /* 2) Resolver materia por CODIGO */
  IF v_abort = 0 THEN
    SET v_not_found = 0;
    SELECT id_Materia
      INTO v_id_materia
      FROM materia
     WHERE codigo = TRIM(p_codigo_materia)
     FOR UPDATE;
    IF v_not_found = 1 THEN
      ROLLBACK; SET v_abort=1; SET v_msg='MATERIA_NO_ENCONTRADA';
    END IF;
  END IF;

  IF v_abort = 1 THEN
    SET p_status = v_msg;

  ELSE
    /* 4) ¿ya existe (plan, materia)? */
    SET v_not_found = 0;
    SELECT 1 INTO v_dummy
      FROM pensum
     WHERE id_Plan_Estudio = v_id_plan_estudio
       AND id_Materia      = v_id_materia
     FOR UPDATE;

    IF v_not_found = 0 THEN
      -- Existe: si cambió el estado, actualiza; si no, informa
      IF EXISTS (
          SELECT 1
            FROM pensum
           WHERE id_Plan_Estudio = v_id_plan_estudio
             AND id_Materia      = v_id_materia
             AND estado_pensum  <> v_estado
      ) THEN
        UPDATE pensum
           SET estado_pensum = v_estado
         WHERE id_Plan_Estudio = v_id_plan_estudio
           AND id_Materia      = v_id_materia;
        COMMIT; SET p_status = 'ACTUALIZADO';
      ELSE
        COMMIT; SET p_status = 'YA_EXISTE';
      END IF;
    ELSE
      INSERT INTO pensum (id_Plan_Estudio, id_Materia, estado_pensum)
      VALUES (v_id_plan_estudio, v_id_materia, v_estado);
      COMMIT; SET p_status = 'OK';
    END IF;
  END IF;
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `PeriodoAcademico_Insertar` (IN `p_anio` SMALLINT UNSIGNED, IN `p_semestre` TINYINT UNSIGNED, IN `p_modulo` TINYINT UNSIGNED, IN `p_estado` VARCHAR(20), OUT `p_id_per` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_estado ENUM('PLANIFICADO','ACTIVO','CERRADO');
  DECLARE v_not_found TINYINT DEFAULT 0;
  DECLARE v_tmp BIGINT UNSIGNED;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET v_estado = CASE UPPER(IFNULL(p_estado,'PLANIFICADO'))
                   WHEN 'ACTIVO'  THEN 'ACTIVO'
                   WHEN 'CERRADO' THEN 'CERRADO'
                   ELSE 'PLANIFICADO'
                 END;

  IF p_anio IS NULL OR p_anio < 2000 THEN
    SET p_id_per = NULL; SET p_status = 'ANIO_INVALIDO'; LEAVE proc;
  END IF;
  IF p_semestre IS NULL OR p_semestre < 1 THEN
    SET p_id_per = NULL; SET p_status = 'SEMESTRE_INVALIDO'; LEAVE proc;
  END IF;
  IF p_modulo IS NULL OR p_modulo < 1 THEN
    SET p_id_per = NULL; SET p_status = 'MODULO_INVALIDO'; LEAVE proc;
  END IF;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT id_Periodo_Academico INTO v_tmp
    FROM periodo_academico
   WHERE anio     = p_anio
     AND semestre = p_semestre
     AND modulo   = p_modulo
   FOR UPDATE;

  IF v_not_found = 0 THEN
    ROLLBACK;
    SET p_id_per = v_tmp;
    SET p_status = 'YA_EXISTE';
    LEAVE proc;
  END IF;

  INSERT INTO periodo_academico (anio, semestre, modulo, estado)
  VALUES (p_anio, p_semestre, p_modulo, v_estado);

  SET p_id_per = LAST_INSERT_ID();
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Permiso_Insertar` (IN `p_codigo` VARCHAR(80), IN `p_descripcion` VARCHAR(200), OUT `p_id_permiso` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_codigo VARCHAR(80);
  DECLARE v_desc   VARCHAR(200);
  DECLARE v_tmp    BIGINT UNSIGNED;
  DECLARE v_not_found TINYINT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR 1062
  BEGIN
    ROLLBACK;
    SET p_id_permiso = NULL;
    SET p_status = 'CODIGO_DUPLICADO';
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET v_codigo = UPPER(TRIM(p_codigo));
  SET v_desc   = TRIM(p_descripcion);

  IF v_codigo = '' OR v_desc = '' THEN
    SET p_id_permiso = NULL; 
    SET p_status = 'PARAMETROS_INVALIDOS';
    LEAVE proc;
  END IF;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT id_Permiso INTO v_tmp
    FROM permiso
    WHERE codigo = v_codigo
    FOR UPDATE;

  IF v_not_found = 0 THEN
    ROLLBACK;
    SET p_id_permiso = NULL;
    SET p_status = 'CODIGO_DUPLICADO';
    LEAVE proc;
  END IF;

  INSERT INTO permiso (codigo, descripcion)
  VALUES (v_codigo, v_desc);

  SET p_id_permiso = LAST_INSERT_ID();
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Persona_Insertar` (IN `p_ci` VARCHAR(25), IN `p_nombre` VARCHAR(100), IN `p_apellido` VARCHAR(100), IN `p_fecha_nacimiento` DATE, IN `p_sexo` CHAR(1), OUT `p_id_persona` BIGINT, OUT `p_status` VARCHAR(32))   BEGIN

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN
        ROLLBACK;
        SET p_id_persona = NULL;
        SET p_status     = 'ERROR';
    END;

    BEGIN
        ROLLBACK;
        SET p_id_persona = NULL;
        SET p_status     = 'CI_DUPLICADO';
    END;

    START TRANSACTION;

        INSERT INTO persona (ci, nombre, apellido, fecha_nacimiento, sexo)
        VALUES (p_ci, p_nombre, p_apellido, p_fecha_nacimiento, p_sexo);

        SET p_id_persona = LAST_INSERT_ID();

    COMMIT;

    SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Plan_Estudio_Insertar` (IN `p_nro_plan` VARCHAR(30), IN `p_descripcion` VARCHAR(200), IN `p_estado` VARCHAR(10), IN `p_fecha_creacion` DATE, IN `p_nro_registro_est` VARCHAR(30), IN `p_codigo_carrera` VARCHAR(30), OUT `p_id_plan` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_not_found   TINYINT DEFAULT 0;
  DECLARE v_id_est      BIGINT  UNSIGNED;
  DECLARE v_id_carr     BIGINT  UNSIGNED;
  DECLARE v_dummy       BIGINT  UNSIGNED;
  DECLARE v_estado      ENUM('ACTIVO','INACTIVO');

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  SET v_estado = CASE UPPER(COALESCE(p_estado,'ACTIVO'))
                   WHEN 'ACTIVO'   THEN 'ACTIVO'
                   WHEN 'INACTIVO' THEN 'INACTIVO'
                   ELSE 'ACTIVO'
                 END;

  IF p_nro_plan IS NULL OR TRIM(p_nro_plan) = '' THEN
    SET p_id_plan = NULL; SET p_status = 'NRO_PLAN_INVALIDO'; LEAVE proc;
  END IF;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  /* 1) Resolver CARRERA por CODIGO  */
  SET v_not_found = 0;
  SELECT id_Carrera
    INTO v_id_carr
    FROM carrera
   WHERE codigo = TRIM(p_codigo_carrera)
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK; SET p_id_plan = NULL; SET p_status = 'CARRERA_NO_ENCONTRADA_POR_CODIGO'; LEAVE proc;
  END IF;

  /* 2) Resolver ESTUDIANTE por NRO_REGISTRO */
  IF p_nro_registro_est IS NOT NULL AND TRIM(p_nro_registro_est) <> '' THEN
    SET v_not_found = 0;
    SELECT id_Estudiante
      INTO v_id_est
      FROM estudiante
     WHERE nro_registro = TRIM(p_nro_registro_est)
     FOR UPDATE;

    IF v_not_found = 1 THEN
      ROLLBACK; SET p_id_plan = NULL; SET p_status = 'ESTUDIANTE_NO_ENCONTRADO_POR_REGISTRO'; LEAVE proc;
    END IF;
  ELSE
    SET v_id_est = NULL;  -- se permite plan sin estudiante asignado
  END IF;

  /* 3) Unicidad de nro_Plan */
  SET v_not_found = 0;
  SELECT id_Plan_Estudio
    INTO v_dummy
    FROM plan_estudio
   WHERE nro_Plan = TRIM(p_nro_plan)
   FOR UPDATE;

  IF v_not_found = 0 THEN
    ROLLBACK; SET p_id_plan = NULL; SET p_status = 'NRO_PLAN_DUPLICADO'; LEAVE proc;
  END IF;

  INSERT INTO plan_estudio
        (nro_Plan, descripcion, estado, fecha_creacion, id_Estudiante, id_Carrera)
  VALUES (TRIM(p_nro_plan), p_descripcion, v_estado, p_fecha_creacion, v_id_est, v_id_carr);

  SET p_id_plan = LAST_INSERT_ID();
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `PromedioFinal_Estudiante` (IN `p_nro_registro` VARCHAR(30), OUT `p_promedio` INT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  /* ===== Variables ===== */
  DECLARE v_not_found   TINYINT DEFAULT 0;
  DECLARE v_id_est      BIGINT UNSIGNED;
  DECLARE v_prom_local  INT;

  /* ===== Handlers ===== */
  -- Error inesperado: deshacer y relanzar
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_promedio = NULL;
    SET p_status   = 'ERROR';
    RESIGNAL;
  END;

  -- SELECT ... INTO sin filas
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = 1;

  /* ===== Validación rápida ===== */
  IF p_nro_registro IS NULL OR TRIM(p_nro_registro) = '' THEN
    SET p_promedio = NULL; 
    SET p_status   = 'NRO_REGISTRO_REQUERIDO';
    LEAVE proc;
  END IF;

  /* ===== Aislamiento + transacción ===== */
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  /* 1) Verificar que el estudiante exista */
  SET v_not_found = 0;
  SELECT id_Estudiante
    INTO v_id_est
    FROM estudiante
   WHERE nro_registro = TRIM(p_nro_registro)
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK;
    SET p_promedio = NULL; 
    SET p_status   = 'ESTUDIANTE_NO_ENCONTRADO';
    LEAVE proc;
  END IF;

  SET v_prom_local = fn_promedio_final_estudiante(TRIM(p_nro_registro));

  /* 3) Resultado */
  IF v_prom_local IS NULL THEN
    COMMIT;
    SET p_promedio = NULL; 
    SET p_status   = 'SIN_NOTAS';
    LEAVE proc;
  END IF;

  SET p_promedio = v_prom_local;
  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `RolPermiso_Insertar` (IN `p_nombre_rol` VARCHAR(80), IN `p_codigo_permiso` VARCHAR(80), OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_not_found   TINYINT DEFAULT 0;
  DECLARE v_id_rol      BIGINT UNSIGNED;
  DECLARE v_id_permiso  BIGINT UNSIGNED;
  DECLARE v_dummy       BIGINT UNSIGNED;


  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;


  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;


  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;


  SET v_not_found = 0;
  SELECT id_Rol
    INTO v_id_rol
    FROM rol
   WHERE nombre = p_nombre_rol
   FOR UPDATE;
  IF v_not_found = 1 THEN
    ROLLBACK; SET p_status = 'ROL_NO_ENCONTRADO'; LEAVE proc;
  END IF;

 
  SET v_not_found = 0;
  SELECT id_Permiso
    INTO v_id_permiso
    FROM permiso
   WHERE codigo = p_codigo_permiso
   FOR UPDATE;
  IF v_not_found = 1 THEN
    ROLLBACK; SET p_status = 'PERMISO_NO_ENCONTRADO'; LEAVE proc;
  END IF;


  SET v_not_found = 0;
  SELECT 1 INTO v_dummy
    FROM rol_permiso
   WHERE id_Rol = v_id_rol
     AND id_Permiso = v_id_permiso
   FOR UPDATE;
  IF v_not_found = 0 THEN
    ROLLBACK; SET p_status = 'YA_ASIGNADO'; LEAVE proc;
  END IF;


  INSERT INTO rol_permiso (id_Rol, id_Permiso)
  VALUES (v_id_rol, v_id_permiso);

  COMMIT;
  SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Rol_Insertar` (IN `p_nombre_rol` VARCHAR(80), OUT `p_id_rol` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
    DECLARE v_id_rol    BIGINT UNSIGNED;
    DECLARE v_not_found TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_not_found = 1;
    END;

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

    START TRANSACTION;

        SET v_not_found = 0;
        SELECT id_Rol
          INTO v_id_rol
          FROM rol
         WHERE nombre = p_nombre_rol
         FOR UPDATE;

        IF v_not_found = 0 THEN
            SET p_id_rol = v_id_rol;
            COMMIT;
            SET p_status = 'EXISTENTE';
            LEAVE proc;
        END IF;

        INSERT INTO rol (nombre, fecha_creacion)
        VALUES (p_nombre_rol, CONVERT_TZ(NOW(), '+00:00', '-04:00'));

        SET p_id_rol = LAST_INSERT_ID();

    COMMIT;
    SET p_status = 'CREADO';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `UsuarioRol_Asignar` (IN `p_ci` VARCHAR(20), IN `p_nombre_rol` VARCHAR(80), OUT `p_status` VARCHAR(32))   proc:BEGIN
    DECLARE v_id_usuario BIGINT UNSIGNED;
    DECLARE v_id_rol     BIGINT UNSIGNED;
    DECLARE v_dummy      BIGINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

        SELECT u.id_Usuario
          INTO v_id_usuario
          FROM usuario u
          JOIN persona p ON p.id_Persona = u.id_Usuario
         WHERE p.ci = p_ci
         FOR UPDATE;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_NO_ENCONTRADO_POR_CI';
        END IF;

        SELECT id_Rol
          INTO v_id_rol
          FROM rol
         WHERE nombre = p_nombre_rol
         FOR UPDATE;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ROL_NO_ENCONTRADO_POR_NOMBRE';
        END IF;

        SELECT 1 INTO v_dummy
          FROM usuario_rol
         WHERE id_Usuario = v_id_usuario
           AND id_Rol     = v_id_rol
         FOR UPDATE;

        IF ROW_COUNT() > 0 THEN
            COMMIT;
            SET p_status = 'YA_ASIGNADO';
            LEAVE proc;
        END IF;

        INSERT INTO usuario_rol (id_Usuario, id_Rol, estado_rol_usuario)
        VALUES (v_id_usuario, v_id_rol, 'ACTIVO');

    COMMIT;
    SET p_status = 'OK';
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` PROCEDURE `Usuario_Insertar` (IN `p_ci` VARCHAR(20), IN `p_password` VARCHAR(255), IN `p_email` VARCHAR(120), OUT `p_id_usuario` BIGINT UNSIGNED, OUT `p_status` VARCHAR(32))   proc:BEGIN
  DECLARE v_tmp         BIGINT UNSIGNED;
  DECLARE v_id_persona  BIGINT UNSIGNED;
  DECLARE v_not_found   TINYINT DEFAULT 0;


  DECLARE EXIT HANDLER FOR 1062
  BEGIN
    ROLLBACK; SET p_id_usuario = NULL; SET p_status = 'EMAIL_DUPLICADO';
  END;

  DECLARE EXIT HANDLER FOR 3819
  BEGIN
    ROLLBACK; SET p_id_usuario = NULL; SET p_status = 'EMAIL_INVALIDO';
  END;

  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET v_not_found = 1;
  END;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK; SET p_id_usuario = NULL; SET p_status = 'ERROR_SQL';
  END;

  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SET v_not_found = 0;
  SELECT id_Persona
    INTO v_id_persona
    FROM persona
   WHERE ci = p_ci
   FOR UPDATE;

  IF v_not_found = 1 THEN
    ROLLBACK; SET p_id_usuario = NULL; SET p_status = 'PERSONA_NO_ENCONTRADA';
    LEAVE proc;
  END IF;

  SET v_not_found = 0;
  SELECT id_Usuario
    INTO v_tmp
    FROM usuario
   WHERE id_Usuario = v_id_persona
   FOR UPDATE;

  IF v_not_found = 0 THEN
    ROLLBACK; SET p_id_usuario = NULL; SET p_status = 'USUARIO_YA_EXISTE';
    LEAVE proc;
  END IF;


  INSERT INTO usuario (id_Usuario, password, email, estado_usuario)
  VALUES (v_id_persona, p_password, p_email, 'ACTIVO');

  SET p_id_usuario = v_id_persona;
  SET p_status = 'OK';
  COMMIT;
END$$

--
-- Functions
--
CREATE DEFINER=`u605613151_admin`@`127.0.0.1` FUNCTION `fn_CantidadEstudiantesCarrera` (`p_id_carrera` BIGINT UNSIGNED) RETURNS INT(10) UNSIGNED DETERMINISTIC READS SQL DATA SQL SECURITY INVOKER BEGIN
  DECLARE v_done       TINYINT DEFAULT 0;
  DECLARE v_id_est     BIGINT UNSIGNED;
  DECLARE v_total      INT UNSIGNED DEFAULT 0;
  DECLARE v_estado_est ENUM('REGULAR','BAJA','SUSPENDIDO');
  DECLARE v_has_activo TINYINT;

  DECLARE cur_est CURSOR FOR
    SELECT DISTINCT e.id_Estudiante
    FROM estudiante e
    JOIN plan_estudio pe
      ON pe.id_Estudiante = e.id_Estudiante
    WHERE pe.id_Carrera = p_id_carrera;


  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  IF p_id_carrera IS NULL THEN
    RETURN 0;
  END IF;

  OPEN cur_est;
  read_loop: LOOP
    FETCH cur_est INTO v_id_est;
    IF v_done = 1 THEN
      LEAVE read_loop;
    END IF;

    SELECT e.estado INTO v_estado_est
    FROM estudiante e
    WHERE e.id_Estudiante = v_id_est
    LIMIT 1;

    IF v_estado_est <> 'REGULAR' THEN
      ITERATE read_loop;
    END IF;
    
    SELECT EXISTS(
             SELECT 1
             FROM plan_estudio pe
             WHERE pe.id_Estudiante = v_id_est
               AND pe.id_Carrera    = p_id_carrera
               AND pe.estado        = 'ACTIVO'
           ) INTO v_has_activo;

    IF v_has_activo = 0 THEN
      ITERATE read_loop;
    END IF;

    SET v_total = v_total + 1;

  END LOOP;
  CLOSE cur_est;

  RETURN v_total;
END$$

CREATE DEFINER=`u605613151_admin`@`127.0.0.1` FUNCTION `fn_promedio_final_estudiante` (`p_nro_registro` VARCHAR(30)) RETURNS INT(10) UNSIGNED DETERMINISTIC READS SQL DATA SQL SECURITY INVOKER BEGIN
  DECLARE v_id_estudiante BIGINT UNSIGNED;
  DECLARE v_promedio DECIMAL(10,4);
  DECLARE v_entero   INT UNSIGNED;
  DECLARE v_frac     DECIMAL(10,4);

  -- Resolver el id_Estudiante a partir del nro_registro
  SELECT e.id_Estudiante
    INTO v_id_estudiante
    FROM estudiante e
   WHERE e.nro_registro = TRIM(p_nro_registro)
   LIMIT 1;

  IF v_id_estudiante IS NULL THEN
    RETURN NULL;
  END IF;

  /* Promedio set-based considerando última corrección si existe */
  SELECT AVG(COALESCE(c.valor_nuevo, np.valor))
    INTO v_promedio
    FROM nota_parcial np
    LEFT JOIN (
      SELECT c1.id_Nota_Parcial, c1.valor_nuevo
      FROM correcion_nota c1
      JOIN (
        SELECT id_Nota_Parcial, MAX(fecha_correcion) AS max_fecha
        FROM correcion_nota
        GROUP BY id_Nota_Parcial
      ) ult
        ON ult.id_Nota_Parcial = c1.id_Nota_Parcial
       AND ult.max_fecha       = c1.fecha_correcion
    ) c
      ON c.id_Nota_Parcial = np.id_Nota_Parcial
   WHERE np.id_Estudiante = v_id_estudiante;

  IF v_promedio IS NULL THEN
    RETURN NULL;
  END IF;

  SET v_entero = FLOOR(v_promedio);
  SET v_frac   = v_promedio - v_entero;

  IF v_frac >= 0.5 THEN
    RETURN v_entero + 1;
  ELSE
    RETURN v_entero;
  END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `apertura_caja`
--

CREATE TABLE `apertura_caja` (
  `id_Apertura_Caja` bigint(20) UNSIGNED NOT NULL,
  `fecha_apertura` timestamp NOT NULL DEFAULT current_timestamp(),
  `fecha_cierre` timestamp NULL DEFAULT NULL,
  `estado` enum('ABIERTA','CERRADA') NOT NULL DEFAULT 'ABIERTA',
  `id_Caja` bigint(20) UNSIGNED NOT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL
) ;

--
-- Dumping data for table `apertura_caja`
--

INSERT INTO `apertura_caja` (`id_Apertura_Caja`, `fecha_apertura`, `fecha_cierre`, `estado`, `id_Caja`, `id_Usuario`) VALUES
(26, '2025-08-19 08:43:05', '2025-08-19 11:42:44', 'ABIERTA', 21, 4),
(27, '2025-08-21 09:43:05', '2025-08-21 19:35:41', 'ABIERTA', 22, 4),
(28, '2025-08-22 13:43:05', '2025-08-22 20:36:19', 'ABIERTA', 23, 4),
(29, '2025-08-25 07:43:05', '2025-08-25 14:36:37', 'ABIERTA', 24, 4),
(30, '2025-08-28 12:43:05', '2025-08-28 19:36:54', 'ABIERTA', 25, 4);

-- --------------------------------------------------------

--
-- Table structure for table `asistencia`
--

CREATE TABLE `asistencia` (
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Oferta_Materia` bigint(20) UNSIGNED NOT NULL,
  `fecha` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `asistencia`
--

INSERT INTO `asistencia` (`id_Estudiante`, `id_Oferta_Materia`, `fecha`) VALUES
(1, 1, '2025-08-27'),
(6, 1, '2025-08-19'),
(8, 2, '2025-08-20'),
(9, 1, '2025-08-28'),
(9, 3, '2025-08-21'),
(10, 4, '2025-08-22');

--
-- Triggers `asistencia`
--
DELIMITER $$
CREATE TRIGGER `trg_asistencia_bi_no_dup` BEFORE INSERT ON `asistencia` FOR EACH ROW BEGIN
  IF EXISTS (
    SELECT 1
      FROM asistencia a
     WHERE a.id_Estudiante = NEW.id_Estudiante
       AND a.fecha = NEW.fecha
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Asistencia duplicada: mismo estudiante y fecha',
          MYSQL_ERRNO = 1644;
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `aula`
--

CREATE TABLE `aula` (
  `id_Aula` bigint(20) UNSIGNED NOT NULL,
  `codigo` varchar(30) NOT NULL,
  `capacidad` int(10) UNSIGNED NOT NULL,
  `descripcion` varchar(150) DEFAULT NULL,
  `bloque` varchar(30) DEFAULT NULL,
  `id_Tipo_Aula` bigint(20) UNSIGNED NOT NULL
) ;

--
-- Dumping data for table `aula`
--

INSERT INTO `aula` (`id_Aula`, `codigo`, `capacidad`, `descripcion`, `bloque`, `id_Tipo_Aula`) VALUES
(1, '222', 30, 'Aula con laptos equipadas con office', 'BLOQUE NORTE', 1),
(2, '5555', 20, 'ciencia', 'Este', 5);

-- --------------------------------------------------------

--
-- Table structure for table `caja`
--

CREATE TABLE `caja` (
  `id_Caja` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `caja`
--

INSERT INTO `caja` (`id_Caja`, `nombre`) VALUES
(21, 'Caja Central A'),
(22, 'Caja Central B'),
(25, 'Caja Este'),
(24, 'Caja Norte'),
(23, 'Caja Sur');

-- --------------------------------------------------------

--
-- Table structure for table `carrera`
--

CREATE TABLE `carrera` (
  `id_Carrera` bigint(20) UNSIGNED NOT NULL,
  `codigo` varchar(30) NOT NULL,
  `nombre` varchar(200) NOT NULL,
  `fecha_creacion` date DEFAULT NULL,
  `id_Facultad` bigint(20) UNSIGNED NOT NULL,
  `id_usuario` bigint(20) UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `carrera`
--

INSERT INTO `carrera` (`id_Carrera`, `codigo`, `nombre`, `fecha_creacion`, `id_Facultad`, `id_usuario`) VALUES
(1, '7815', 'Ingeniería de Sistemas', '2016-08-09', 1, 1),
(2, '4874', 'Ingeniería de Sistemas y Electronica', '2022-06-01', 1, 1),
(3, '1102', 'CONTABILIDAD', '2025-11-02', 2, 1),
(4, '1111', 'Diseño Grafico', '2021-01-01', 5, 1),
(5, '9999', 'Marketing Publicidad', '2022-01-01', 5, 1);

-- --------------------------------------------------------

--
-- Table structure for table `convalidacion_externa`
--

CREATE TABLE `convalidacion_externa` (
  `id_Convalidacion_Ext` bigint(20) UNSIGNED NOT NULL,
  `fecha` date NOT NULL,
  `universidad_origen` varchar(150) NOT NULL,
  `observaciones` varchar(250) DEFAULT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `convalidacion_externa`
--

INSERT INTO `convalidacion_externa` (`id_Convalidacion_Ext`, `fecha`, `universidad_origen`, `observaciones`, `id_Estudiante`, `id_Usuario`) VALUES
(1, '2025-08-20', 'Universidad Autónoma Gabriel René Moreno', 'Traspaso asignaturas básicas', 1, 1),
(2, '2025-08-28', 'Universidad Mayor de San Andrés', 'Equivalencias de tronco común', 6, 1),
(3, '2025-08-28', 'Universidad Católica Boliviana', 'Equivalencia por traslado', 8, 1);

-- --------------------------------------------------------

--
-- Table structure for table `convalidacion_externa_detalle`
--

CREATE TABLE `convalidacion_externa_detalle` (
  `id_Convalidacion_Ext` bigint(20) UNSIGNED NOT NULL,
  `id_Materia` bigint(20) UNSIGNED NOT NULL,
  `nota` decimal(5,2) NOT NULL,
  `materia_origen` varchar(150) DEFAULT NULL,
  `materia_destino` varchar(150) DEFAULT NULL
) ;

--
-- Dumping data for table `convalidacion_externa_detalle`
--

INSERT INTO `convalidacion_externa_detalle` (`id_Convalidacion_Ext`, `id_Materia`, `nota`, `materia_origen`, `materia_destino`) VALUES
(3, 1, 79.00, 'Gestión de Datos (UCB)', 'BD (Plan destino)'),
(3, 3, 84.00, 'Sistemas Operativos (UCB)', 'SO (Plan destino)');

-- --------------------------------------------------------

--
-- Table structure for table `convalidacion_interna`
--

CREATE TABLE `convalidacion_interna` (
  `id_Convalidacion_Inte` bigint(20) UNSIGNED NOT NULL,
  `fecha` date NOT NULL,
  `motivo` varchar(200) DEFAULT NULL,
  `observaciones` varchar(250) DEFAULT NULL,
  `id_Plan_Estudio_origen` bigint(20) UNSIGNED NOT NULL,
  `id_Plan_Estudio_destino` bigint(20) UNSIGNED NOT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `convalidacion_interna`
--

INSERT INTO `convalidacion_interna` (`id_Convalidacion_Inte`, `fecha`, `motivo`, `observaciones`, `id_Plan_Estudio_origen`, `id_Plan_Estudio_destino`, `id_Estudiante`, `id_Usuario`) VALUES
(1, '2025-08-28', 'Equivalencia por cambio de plan', 'Solicitud interna generada por el sistema', 1, 2, 1, 1),
(2, '2025-08-28', 'Cambio de plan académico', 'Solicitud generada en reinscripción', 2, 1, 6, 1);

-- --------------------------------------------------------

--
-- Table structure for table `convalidacion_interna_detalle`
--

CREATE TABLE `convalidacion_interna_detalle` (
  `id_Convalidacion_Inte` bigint(20) UNSIGNED NOT NULL,
  `id_Materia` bigint(20) UNSIGNED NOT NULL,
  `nota_homologacion` decimal(5,2) NOT NULL,
  `materia_origen` varchar(150) DEFAULT NULL,
  `materia_destino` varchar(150) DEFAULT NULL
) ;

--
-- Dumping data for table `convalidacion_interna_detalle`
--

INSERT INTO `convalidacion_interna_detalle` (`id_Convalidacion_Inte`, `id_Materia`, `nota_homologacion`, `materia_origen`, `materia_destino`) VALUES
(1, 1, 85.00, 'BD (Plan 0007)', 'BD (Plan 001)'),
(2, 2, 90.00, 'IA (Plan 001)', 'IA (Plan 0007)');

-- --------------------------------------------------------

--
-- Table structure for table `correcion_nota`
--

CREATE TABLE `correcion_nota` (
  `id_Correcion_Nota` bigint(20) UNSIGNED NOT NULL,
  `valor_anterior` decimal(5,2) NOT NULL,
  `valor_nuevo` decimal(5,2) NOT NULL,
  `fecha_correcion` timestamp NOT NULL DEFAULT current_timestamp(),
  `motivo` varchar(200) DEFAULT NULL,
  `id_Nota_Parcial` bigint(20) UNSIGNED NOT NULL
) ;

--
-- Dumping data for table `correcion_nota`
--

INSERT INTO `correcion_nota` (`id_Correcion_Nota`, `valor_anterior`, `valor_nuevo`, `fecha_correcion`, `motivo`, `id_Nota_Parcial`) VALUES
(1, 80.00, 90.00, '2025-08-28 15:16:32', 'Un mal conteo', 2),
(2, 90.00, 68.00, '2025-08-28 16:03:46', 'Error de promedio', 5);

--
-- Triggers `correcion_nota`
--
DELIMITER $$
CREATE TRIGGER `trg_correcion_nota_ai_apply` AFTER INSERT ON `correcion_nota` FOR EACH ROW BEGIN
  UPDATE nota_parcial
     SET valor = NEW.valor_nuevo,
         observacion = CONCAT(COALESCE(observacion,''),' [Corregido el ',
                              DATE_FORMAT(NEW.fecha_correcion,'%Y-%m-%d %H:%i:%s'),']')
   WHERE id_Nota_Parcial = NEW.id_Nota_Parcial;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_correcion_nota_bi_fill` BEFORE INSERT ON `correcion_nota` FOR EACH ROW BEGIN
  DECLARE v_actual DECIMAL(5,2);
  SELECT valor INTO v_actual
    FROM nota_parcial
   WHERE id_Nota_Parcial = NEW.id_Nota_Parcial;

  SET NEW.valor_anterior = v_actual;

  IF NEW.valor_nuevo < 0 OR NEW.valor_nuevo > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nota nueva debe estar entre 0 y 100';
  END IF;

  IF NEW.valor_nuevo = v_actual THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La corrección no cambia el valor';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `docente`
--

CREATE TABLE `docente` (
  `id_Docente` bigint(20) UNSIGNED NOT NULL,
  `fecha_contratacion` date NOT NULL,
  `estado` enum('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `certificacion` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `docente`
--

INSERT INTO `docente` (`id_Docente`, `fecha_contratacion`, `estado`, `certificacion`) VALUES
(3, '2025-08-12', 'ACTIVO', 'BASEDEDATOS'),
(5, '2019-08-12', 'ACTIVO', 'IA'),
(7, '2002-03-09', 'ACTIVO', 'CISCO'),
(2001, '2020-02-01', 'ACTIVO', 'Postgrado en Educación');

-- --------------------------------------------------------

--
-- Table structure for table `documento_estudiante`
--

CREATE TABLE `documento_estudiante` (
  `id_Documento_estudiante` bigint(20) UNSIGNED NOT NULL,
  `estado` enum('PENDIENTE','APROBADO','RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
  `fecha_registro` timestamp NOT NULL DEFAULT current_timestamp(),
  `observacion` varchar(200) DEFAULT NULL,
  `direccion_doc` varchar(250) DEFAULT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Tipo_Documento` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `documento_estudiante`
--

INSERT INTO `documento_estudiante` (`id_Documento_estudiante`, `estado`, `fecha_registro`, `observacion`, `direccion_doc`, `id_Estudiante`, `id_Tipo_Documento`) VALUES
(11, 'PENDIENTE', '2025-08-28 15:47:42', 'Certificado de Nacimiento', '/docs/1.pdf', 1, 1),
(12, 'PENDIENTE', '2025-08-28 15:47:42', 'Fotocopia CI', '/docs/6.pdf', 6, 2),
(13, 'PENDIENTE', '2025-08-28 15:47:42', 'Título Bachiller', '/docs/8.pdf', 8, 3),
(14, 'PENDIENTE', '2025-08-28 15:47:42', 'Kardex', '/docs/9.pdf', 9, 4),
(15, 'PENDIENTE', '2025-08-28 15:47:42', 'Formulario Inscripción', '/docs/10.pdf', 10, 5);

-- --------------------------------------------------------

--
-- Table structure for table `estudiante`
--

CREATE TABLE `estudiante` (
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `nro_registro` varchar(30) NOT NULL,
  `estado` enum('REGULAR','BAJA','SUSPENDIDO') NOT NULL DEFAULT 'REGULAR'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `estudiante`
--

INSERT INTO `estudiante` (`id_Estudiante`, `nro_registro`, `estado`) VALUES
(1, '114244', 'REGULAR'),
(6, '849741', 'REGULAR'),
(8, '10023', 'REGULAR'),
(9, '100230', 'REGULAR'),
(10, '602204', 'REGULAR'),
(1001, '1001', 'REGULAR');

-- --------------------------------------------------------

--
-- Table structure for table `facultad`
--

CREATE TABLE `facultad` (
  `id_Facultad` bigint(20) UNSIGNED NOT NULL,
  `codigo` varchar(30) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `fecha_creacion` date DEFAULT NULL,
  `id_Universidad` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `facultad`
--

INSERT INTO `facultad` (`id_Facultad`, `codigo`, `nombre`, `fecha_creacion`, `id_Universidad`) VALUES
(1, '665', 'Tecnología y Redes', '2016-08-09', 1),
(2, '10', 'FISICA', '2025-11-02', 1),
(3, '125', 'REDES', '2018-11-02', 1),
(4, '7001', 'CIENCIA Y TECNOLOGIA', '2022-11-02', 1),
(5, '100235', 'Faculta Empresarial', '2018-11-02', 1);

-- --------------------------------------------------------

--
-- Table structure for table `horario`
--

CREATE TABLE `horario` (
  `id_Horario` bigint(20) UNSIGNED NOT NULL,
  `hora_inicio` time NOT NULL,
  `hora_fin` time NOT NULL
) ;

--
-- Dumping data for table `horario`
--

INSERT INTO `horario` (`id_Horario`, `hora_inicio`, `hora_fin`) VALUES
(1, '08:00:00', '13:00:00'),
(2, '13:00:00', '16:00:00'),
(3, '18:00:00', '22:00:00'),
(4, '07:00:00', '12:35:00');

-- --------------------------------------------------------

--
-- Table structure for table `inscripcion_estudiante`
--

CREATE TABLE `inscripcion_estudiante` (
  `id_Inscripcion_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `fecha_inscripcion` timestamp NOT NULL DEFAULT current_timestamp(),
  `estado` enum('ACTIVA','ANULADA') NOT NULL DEFAULT 'ACTIVA',
  `observaciones` varchar(200) DEFAULT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `inscripcion_estudiante`
--

INSERT INTO `inscripcion_estudiante` (`id_Inscripcion_Estudiante`, `id_Estudiante`, `fecha_inscripcion`, `estado`, `observaciones`, `id_Usuario`) VALUES
(2, 1, '2025-08-28 18:41:58', 'ACTIVA', 'Ingreso gestión', 5),
(3, 6, '2025-08-28 18:41:58', 'ACTIVA', 'Regular', 5),
(4, 8, '2025-08-28 18:41:58', 'ACTIVA', 'Reincorporación', 5),
(5, 9, '2025-08-28 18:41:58', 'ACTIVA', 'Nuevo ingreso', 5),
(6, 10, '2025-08-28 18:41:58', 'ACTIVA', 'Traspaso interno', 5);

-- --------------------------------------------------------

--
-- Table structure for table `materia`
--

CREATE TABLE `materia` (
  `id_Materia` bigint(20) UNSIGNED NOT NULL,
  `codigo` varchar(30) NOT NULL,
  `sigla` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `materia`
--

INSERT INTO `materia` (`id_Materia`, `codigo`, `sigla`) VALUES
(1, '11', 'BD'),
(2, '12', 'IA'),
(3, '05', 'SO'),
(4, '03', 'CALC. 1'),
(5, '07', 'CALC. 2'),
(6, '13', 'INFRAEST.'),
(7, '14', 'INGLÉS TEC. 1'),
(8, '16', 'DES. EMPRES'),
(10, '17', 'REDES INALAMBRICA');

-- --------------------------------------------------------

--
-- Table structure for table `nota_parcial`
--

CREATE TABLE `nota_parcial` (
  `id_Nota_Parcial` bigint(20) UNSIGNED NOT NULL,
  `valor` decimal(5,2) NOT NULL,
  `fecha` date NOT NULL,
  `observacion` varchar(200) DEFAULT NULL,
  `id_Docente` bigint(20) UNSIGNED NOT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Oferta_Materia` bigint(20) UNSIGNED NOT NULL
) ;

--
-- Dumping data for table `nota_parcial`
--

INSERT INTO `nota_parcial` (`id_Nota_Parcial`, `valor`, `fecha`, `observacion`, `id_Docente`, `id_Estudiante`, `id_Oferta_Materia`) VALUES
(2, 0.00, '0000-00-00', NULL, 5, 6, 1),
(3, 72.00, '2025-08-20', 'Primer parcial', 3, 1, 1),
(4, 0.00, '0000-00-00', '', 3, 6, 1),
(5, 68.00, '2025-08-23', 'IA: heurísticas [Corregido el 2025-08-28 16:03:46]', 5, 8, 2),
(6, 66.00, '2025-08-24', 'SO: procesos', 7, 9, 3),
(7, 95.00, '2025-08-25', 'Cálculo 1: series', 3, 10, 4),
(8, 78.00, '2025-08-26', 'Recuperatorio', 3, 1, 1);

--
-- Triggers `nota_parcial`
--
DELIMITER $$
CREATE TRIGGER `trg_nota_parcial_bi_rango` BEFORE INSERT ON `nota_parcial` FOR EACH ROW BEGIN
  IF NEW.valor < 0 OR NEW.valor > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nota debe estar entre 0 y 100';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `oferta_materia`
--

CREATE TABLE `oferta_materia` (
  `id_Oferta_Materia` bigint(20) UNSIGNED NOT NULL,
  `estado` enum('ABIERTA','CERRADA','CANCELADA') NOT NULL DEFAULT 'ABIERTA',
  `cupos` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp(),
  `bloqueo_por_vicerrector` tinyint(1) NOT NULL DEFAULT 0,
  `grupo` varchar(10) NOT NULL,
  `id_Periodo_Academico` bigint(20) UNSIGNED NOT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL,
  `id_Materia` bigint(20) UNSIGNED NOT NULL,
  `id_Docente` bigint(20) UNSIGNED DEFAULT NULL,
  `id_Aula` bigint(20) UNSIGNED DEFAULT NULL,
  `id_Horario` bigint(20) UNSIGNED DEFAULT NULL
) ;

--
-- Dumping data for table `oferta_materia`
--

INSERT INTO `oferta_materia` (`id_Oferta_Materia`, `estado`, `cupos`, `fecha_creacion`, `bloqueo_por_vicerrector`, `grupo`, `id_Periodo_Academico`, `id_Usuario`, `id_Materia`, `id_Docente`, `id_Aula`, `id_Horario`) VALUES
(1, 'ABIERTA', 30, '2025-08-28 02:54:26', 0, 'A', 1, 1, 1, 3, 1, 1),
(2, 'ABIERTA', 35, '2025-08-28 19:10:42', 0, 'B', 1, 1, 2, 5, 2, 2),
(3, 'ABIERTA', 25, '2025-08-28 19:10:42', 0, 'A', 1, 1, 3, 7, 1, 3),
(4, 'ABIERTA', 40, '2025-08-28 19:10:42', 0, 'C', 1, 1, 4, 3, 1, 4);

-- --------------------------------------------------------

--
-- Table structure for table `pago`
--

CREATE TABLE `pago` (
  `id_Pago` bigint(20) UNSIGNED NOT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  `descripcion` varchar(200) DEFAULT NULL,
  `monto` decimal(12,2) NOT NULL,
  `estado` enum('PENDIENTE','PAGADO','ANULADO') NOT NULL DEFAULT 'PENDIENTE',
  `metodo_pago` enum('EFECTIVO','TARJETA','TRANSFERENCIA','OTRO') NOT NULL DEFAULT 'EFECTIVO',
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Usuario` bigint(20) UNSIGNED NOT NULL,
  `id_Apertura_Caja` bigint(20) UNSIGNED NOT NULL
) ;

--
-- Dumping data for table `pago`
--

INSERT INTO `pago` (`id_Pago`, `fecha`, `descripcion`, `monto`, `estado`, `metodo_pago`, `id_Estudiante`, `id_Usuario`, `id_Apertura_Caja`) VALUES
(1, '2025-08-28 19:16:38', 'Pago inscripción gestión', 150.00, 'PAGADO', 'EFECTIVO', 1, 4, 26),
(2, '2025-08-28 19:16:38', 'Pago inscripción gestión', 150.00, 'PAGADO', 'EFECTIVO', 6, 4, 26),
(3, '2025-08-28 19:16:38', 'Pago materia: IA - cuota 1', 200.00, 'PENDIENTE', 'EFECTIVO', 8, 4, 26),
(4, '2025-08-28 19:16:38', 'Pago materia: SO - cuota 1', 200.00, 'PENDIENTE', 'EFECTIVO', 9, 4, 26);

-- --------------------------------------------------------

--
-- Table structure for table `pago_inscripcion`
--

CREATE TABLE `pago_inscripcion` (
  `id_Pago` bigint(20) UNSIGNED NOT NULL,
  `id_Inscripcion_Estudiante` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `pago_inscripcion`
--

INSERT INTO `pago_inscripcion` (`id_Pago`, `id_Inscripcion_Estudiante`) VALUES
(1, 2),
(2, 3);

-- --------------------------------------------------------

--
-- Table structure for table `pago_materia`
--

CREATE TABLE `pago_materia` (
  `id_Pago` bigint(20) UNSIGNED NOT NULL,
  `numero_cuota` int(10) UNSIGNED NOT NULL DEFAULT 1,
  `fecha_vencimiento` date DEFAULT NULL
) ;

--
-- Dumping data for table `pago_materia`
--

INSERT INTO `pago_materia` (`id_Pago`, `numero_cuota`, `fecha_vencimiento`) VALUES
(3, 1, '2025-09-15'),
(4, 1, '2025-09-20');

-- --------------------------------------------------------

--
-- Table structure for table `pensum`
--

CREATE TABLE `pensum` (
  `id_Plan_Estudio` bigint(20) UNSIGNED NOT NULL,
  `id_Materia` bigint(20) UNSIGNED NOT NULL,
  `estado_pensum` enum('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `pensum`
--

INSERT INTO `pensum` (`id_Plan_Estudio`, `id_Materia`, `estado_pensum`) VALUES
(1, 2, 'ACTIVO'),
(2, 1, 'ACTIVO'),
(5, 6, 'ACTIVO'),
(6, 6, 'ACTIVO');

-- --------------------------------------------------------

--
-- Table structure for table `periodo_academico`
--

CREATE TABLE `periodo_academico` (
  `id_Periodo_Academico` bigint(20) UNSIGNED NOT NULL,
  `anio` year(4) NOT NULL,
  `semestre` int(3) UNSIGNED NOT NULL,
  `modulo` int(3) UNSIGNED NOT NULL,
  `estado` enum('ACTIVO','CERRADO','PLANIFICADO') NOT NULL DEFAULT 'PLANIFICADO'
) ;

--
-- Dumping data for table `periodo_academico`
--

INSERT INTO `periodo_academico` (`id_Periodo_Academico`, `anio`, `semestre`, `modulo`, `estado`) VALUES
(1, '2025', 1, 4, 'PLANIFICADO'),
(2, '2025', 1, 3, 'PLANIFICADO'),
(3, '2025', 1, 1, 'PLANIFICADO'),
(4, '2025', 1, 2, 'PLANIFICADO'),
(5, '2025', 1, 5, 'PLANIFICADO');

-- --------------------------------------------------------

--
-- Table structure for table `permiso`
--

CREATE TABLE `permiso` (
  `id_Permiso` bigint(20) UNSIGNED NOT NULL,
  `codigo` varchar(80) NOT NULL,
  `descripcion` varchar(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `permiso`
--

INSERT INTO `permiso` (`id_Permiso`, `codigo`, `descripcion`) VALUES
(1, '110', 'CAJERO');

-- --------------------------------------------------------

--
-- Table structure for table `persona`
--

CREATE TABLE `persona` (
  `id_Persona` bigint(20) UNSIGNED NOT NULL,
  `ci` varchar(20) NOT NULL,
  `nombre` varchar(80) NOT NULL,
  `apellido` varchar(100) NOT NULL,
  `fecha_nacimiento` date DEFAULT NULL,
  `sexo` enum('M','F','X') NOT NULL DEFAULT 'X',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `persona`
--

INSERT INTO `persona` (`id_Persona`, `ci`, `nombre`, `apellido`, `fecha_nacimiento`, `sexo`, `created_at`, `updated_at`) VALUES
(1, '7916161', 'admin', 'php', '2008-08-13', 'M', '2025-08-26 00:03:13', '2025-08-26 00:03:13'),
(3, '456117', 'Alberto', 'Justiniano', '0000-00-00', 'M', '2025-08-26 13:16:40', '2025-08-26 13:16:40'),
(4, '7894512', 'Juliana', 'Salvatierra', '1995-05-15', 'F', '2025-08-26 13:36:50', '2025-08-26 13:36:50'),
(5, '7884181', 'Federico', 'Valverde', '1997-02-22', 'M', '2025-08-26 19:57:44', '2025-08-26 19:57:44'),
(6, '4825101', 'Christian', 'Coronado', '2002-05-08', 'M', '2025-08-27 20:21:01', '2025-08-27 20:21:01'),
(7, '1254874', 'Gilberto', 'Mamani', '1989-06-24', 'M', '2025-08-27 20:43:21', '2025-08-27 20:43:21'),
(8, '81600', 'zoro', 'caballero', '1999-12-02', 'M', '2025-08-28 01:26:48', '2025-08-28 14:34:59'),
(9, '81601', 'NAMI', 'silva', '1990-12-02', 'F', '2025-08-28 01:35:38', '2025-08-28 14:32:45'),
(10, '602204', 'rodrigo', 'Garcia', '2000-05-31', 'M', '2025-08-28 13:20:39', '2025-08-28 14:36:29'),
(1001, 'CI_EST_123', 'Ana', 'Quispe', '2001-05-10', 'F', '2025-08-28 14:32:44', '2025-08-28 14:32:44'),
(2001, 'CI_DOC_987', 'Carlos', 'Lopez', '1985-03-02', 'M', '2025-08-28 14:32:44', '2025-08-28 14:32:44');

-- --------------------------------------------------------

--
-- Table structure for table `plan_estudio`
--

CREATE TABLE `plan_estudio` (
  `id_Plan_Estudio` bigint(20) UNSIGNED NOT NULL,
  `nro_Plan` varchar(30) NOT NULL,
  `descripcion` varchar(200) DEFAULT NULL,
  `estado` enum('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `fecha_creacion` date DEFAULT NULL,
  `id_Estudiante` bigint(20) UNSIGNED DEFAULT NULL,
  `id_Carrera` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `plan_estudio`
--

INSERT INTO `plan_estudio` (`id_Plan_Estudio`, `nro_Plan`, `descripcion`, `estado`, `fecha_creacion`, `id_Estudiante`, `id_Carrera`) VALUES
(1, '0007', 'Becado', 'ACTIVO', '2025-11-02', 1, 1),
(2, '001', 'REGULAR', 'ACTIVO', '2012-11-02', 6, 3),
(5, '0010', 'Extranjero', 'ACTIVO', '2025-09-02', 1001, 4),
(6, '2222', 'Bolivia', 'ACTIVO', '2025-09-01', NULL, 1);

-- --------------------------------------------------------

--
-- Table structure for table `registro_materia`
--

CREATE TABLE `registro_materia` (
  `id_Registro_Materia` bigint(20) UNSIGNED NOT NULL,
  `id_Estudiante` bigint(20) UNSIGNED NOT NULL,
  `id_Oferta_Materia` bigint(20) UNSIGNED NOT NULL,
  `fecha_registro` timestamp NOT NULL DEFAULT current_timestamp(),
  `estado` enum('REGISTRADO','RETIRADO') NOT NULL DEFAULT 'REGISTRADO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `registro_materia`
--

INSERT INTO `registro_materia` (`id_Registro_Materia`, `id_Estudiante`, `id_Oferta_Materia`, `fecha_registro`, `estado`) VALUES
(5, 1, 1, '2025-08-28 19:11:49', 'RETIRADO'),
(6, 6, 1, '2025-08-28 19:11:49', 'REGISTRADO'),
(7, 8, 2, '2025-08-28 19:11:49', 'RETIRADO'),
(8, 9, 3, '2025-08-28 19:11:49', 'REGISTRADO'),
(9, 10, 4, '2025-08-28 19:11:49', 'RETIRADO');

-- --------------------------------------------------------

--
-- Table structure for table `retiro_materia`
--

CREATE TABLE `retiro_materia` (
  `id_Retiro_Materia` bigint(20) UNSIGNED NOT NULL,
  `fecha` date NOT NULL,
  `motivo` varchar(200) DEFAULT NULL,
  `id_Registro_Materia` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `retiro_materia`
--

INSERT INTO `retiro_materia` (`id_Retiro_Materia`, `fecha`, `motivo`, `id_Registro_Materia`) VALUES
(5, '2025-08-13', 'Abandono voluntario', 5),
(6, '2025-08-15', 'Problemas Económico ', 7),
(7, '2025-08-17', 'Motivos de salud', 9);

-- --------------------------------------------------------

--
-- Table structure for table `rol`
--

CREATE TABLE `rol` (
  `id_Rol` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(80) NOT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `rol`
--

INSERT INTO `rol` (`id_Rol`, `nombre`, `fecha_creacion`) VALUES
(2, 'JEFE_CARRERA', '2025-08-26 17:09:43'),
(5, 'ADMINISTRADOR', '2025-08-26 16:50:59'),
(8, 'VICERRECTOR', '2025-08-27 09:56:07'),
(9, 'CAJERA', '2025-08-27 13:47:30'),
(10, 'RECTOR', '2025-08-27 13:48:17'),
(11, 'INSCRIPTOR', '2025-08-28 10:46:55'),
(12, 'TRANSCRIPTOR', '2025-08-28 10:47:26');

-- --------------------------------------------------------

--
-- Table structure for table `rol_permiso`
--

CREATE TABLE `rol_permiso` (
  `id_Rol` bigint(20) UNSIGNED NOT NULL,
  `id_Permiso` bigint(20) UNSIGNED NOT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `rol_permiso`
--

INSERT INTO `rol_permiso` (`id_Rol`, `id_Permiso`, `fecha_creacion`) VALUES
(2, 1, '2025-08-28 00:32:30'),
(9, 1, '2025-08-27 18:17:30');

-- --------------------------------------------------------

--
-- Table structure for table `tipo_aula`
--

CREATE TABLE `tipo_aula` (
  `id_Tipo_Aula` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tipo_aula`
--

INSERT INTO `tipo_aula` (`id_Tipo_Aula`, `nombre`) VALUES
(5, 'LABORATORIO FÍSICA'),
(3, 'LABORATORIO QUÍMICO'),
(1, 'LABORATORIO SISTEMAS'),
(2, 'MAGNA'),
(4, 'NORMALES');

-- --------------------------------------------------------

--
-- Table structure for table `tipo_cuota`
--

CREATE TABLE `tipo_cuota` (
  `id_Tipo_Cuota` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(80) NOT NULL,
  `descripcion` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tipo_cuota`
--

INSERT INTO `tipo_cuota` (`id_Tipo_Cuota`, `nombre`, `descripcion`) VALUES
(1, 'MATERIA_EXAMEN_GRADO', 'Cuota para cancelar una materia de la modalidad exámen de grado.'),
(2, 'MATERIA_SEMESTRAL', 'Cuota para cancelar una materia del plan de estudio de un estudiante.');

-- --------------------------------------------------------

--
-- Table structure for table `tipo_documento`
--

CREATE TABLE `tipo_documento` (
  `id_Tipo_Documento` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tipo_documento`
--

INSERT INTO `tipo_documento` (`id_Tipo_Documento`, `nombre`) VALUES
(2, 'Bachiller'),
(4, 'Certificado Notas'),
(1, 'CI'),
(3, 'Nacimiento'),
(5, 'Otros');

-- --------------------------------------------------------

--
-- Table structure for table `universidad`
--

CREATE TABLE `universidad` (
  `id_Universidad` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `direccion` varchar(200) DEFAULT NULL,
  `nit` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `universidad`
--

INSERT INTO `universidad` (`id_Universidad`, `nombre`, `direccion`, `nit`) VALUES
(1, 'Universidad Nacional Boliviana', 'Av. Noel Kempf / Nro° 456', '5446114');

-- --------------------------------------------------------

--
-- Table structure for table `usuario`
--

CREATE TABLE `usuario` (
  `id_Usuario` bigint(20) UNSIGNED NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(120) NOT NULL,
  `estado_usuario` enum('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `usuario`
--

INSERT INTO `usuario` (`id_Usuario`, `password`, `email`, `estado_usuario`, `created_at`, `updated_at`) VALUES
(1, '123', 'admin@example.com', 'ACTIVO', '2025-08-26 00:09:11', '2025-09-01 14:37:54'),
(3, '10000', 'lm@gmail.com', 'ACTIVO', '2025-08-26 22:03:52', '2025-08-26 22:03:52'),
(4, '456', 'prueba@gmail.com', 'ACTIVO', '2025-08-26 14:42:45', '2025-08-26 14:42:45'),
(5, '987', 'federico@gmail.com', 'ACTIVO', '2025-08-27 20:09:44', '2025-08-27 20:09:44'),
(6, '154', 'christianutepsa@gmail.com', 'ACTIVO', '2025-08-27 20:22:15', '2025-08-27 20:22:15'),
(7, '421', 'gilberto@gmail.com', 'ACTIVO', '2025-08-27 20:43:59', '2025-08-27 20:43:59'),
(8, '10000', 'zoro@gmail.com', 'ACTIVO', '2025-08-28 01:27:18', '2025-08-28 01:27:18'),
(9, '10007', 'nami@gmail.com', 'ACTIVO', '2025-08-28 01:36:05', '2025-08-28 01:36:05'),
(10, 'password', 'mayus@example.com', 'ACTIVO', '2025-08-28 13:21:19', '2025-08-29 17:59:34'),
(1001, '12345', 'ana.quispe@uni.edu', 'ACTIVO', '2025-08-28 14:35:07', '2025-09-01 15:09:31'),
(2001, '12345', 'carlos.lopez@uni.edu', 'ACTIVO', '2025-08-28 14:35:07', '2025-08-28 14:35:07');

-- --------------------------------------------------------

--
-- Table structure for table `usuario_rol`
--

CREATE TABLE `usuario_rol` (
  `id_Usuario` bigint(20) UNSIGNED NOT NULL,
  `id_Rol` bigint(20) UNSIGNED NOT NULL,
  `estado_rol_usuario` enum('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `usuario_rol`
--

INSERT INTO `usuario_rol` (`id_Usuario`, `id_Rol`, `estado_rol_usuario`) VALUES
(1, 2, 'ACTIVO'),
(4, 9, 'ACTIVO'),
(5, 11, 'ACTIVO');

--
-- Triggers `usuario_rol`
--
DELIMITER $$
CREATE TRIGGER `trg_insert_usuario_rol` BEFORE INSERT ON `usuario_rol` FOR EACH ROW BEGIN
    DECLARE es_estudiante BOOLEAN;
    
    -- Verificar si el usuario es un estudiante
    SELECT COUNT(*) INTO es_estudiante 
    FROM estudiante 
    WHERE id_Estudiante = NEW.id_Usuario;
    
    IF es_estudiante THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede asignar roles a usuarios estudiantes';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `validacion_pago`
--

CREATE TABLE `validacion_pago` (
  `id_Validacion_Pago` bigint(20) UNSIGNED NOT NULL,
  `estado` enum('VALIDO','INVALIDO') NOT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  `observacion` varchar(200) DEFAULT NULL,
  `id_Pago` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `validacion_pago`
--

INSERT INTO `validacion_pago` (`id_Validacion_Pago`, `estado`, `fecha`, `observacion`, `id_Pago`) VALUES
(1, 'VALIDO', '2025-08-28 19:55:47', 'Pago de inscripción verificado en caja', 1),
(2, 'VALIDO', '2025-08-28 19:55:47', 'Pago de inscripción confirmado', 2),
(3, 'VALIDO', '2025-08-28 19:55:47', 'Primer cuota de materia registrada en caja', 3),
(4, 'INVALIDO', '2025-08-28 19:55:47', 'Monto inconsistente con recibo original', 4);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_docente_perfil`
-- (See below for the actual view)
--
CREATE TABLE `v_docente_perfil` (
`id` bigint(20) unsigned
,`ci` varchar(20)
,`nombre` varchar(80)
,`apellido` varchar(100)
,`fecha_contratacion` date
,`estado` enum('ACTIVO','INACTIVO')
,`certificacion` varchar(200)
,`email` varchar(120)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_estado_caja`
-- (See below for the actual view)
--
CREATE TABLE `v_estado_caja` (
`id_Caja` bigint(20) unsigned
,`caja` varchar(80)
,`id_Apertura_Caja` bigint(20) unsigned
,`fecha_apertura` timestamp
,`fecha_cierre` timestamp
,`estado` enum('ABIERTA','CERRADA')
,`id_usuario_apertura` bigint(20) unsigned
,`usuario_apertura` varchar(120)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_estudiante_perfil`
-- (See below for the actual view)
--
CREATE TABLE `v_estudiante_perfil` (
`id` bigint(20) unsigned
,`ci` varchar(20)
,`nombre` varchar(80)
,`apellido` varchar(100)
,`nro_registro` varchar(30)
,`estado_estudiante` enum('REGULAR','BAJA','SUSPENDIDO')
,`email` varchar(120)
,`id_Plan_Estudio` bigint(20) unsigned
,`nro_Plan` varchar(30)
,`estado_plan` enum('ACTIVO','INACTIVO')
,`id_Carrera` bigint(20) unsigned
,`codigo_carrera` varchar(30)
,`nombre_carrera` varchar(200)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_inscripcion_estudiante_detalle`
-- (See below for the actual view)
--
CREATE TABLE `v_inscripcion_estudiante_detalle` (
`id_Inscripcion_Estudiante` bigint(20) unsigned
,`fecha_inscripcion` timestamp
,`estado` enum('ACTIVA','ANULADA')
,`observaciones` varchar(200)
,`id_operador` bigint(20) unsigned
,`operador_email` varchar(120)
);

-- --------------------------------------------------------

--
-- Table structure for table `v_nota_parcial_con_ultima_correccion`
--

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_nota_parcial_con_ultima_correccion`  AS SELECT `nd`.`id_Nota_Parcial` AS `id_Nota_Parcial`, `nd`.`tipo` AS `tipo`, `nd`.`valor_original` AS `valor_original`, `nd`.`fecha` AS `fecha`, `nd`.`observacion` AS `observacion`, `nd`.`id_Docente` AS `id_Docente`, `nd`.`docente` AS `docente`, `nd`.`id_Estudiante` AS `id_Estudiante`, `nd`.`estudiante` AS `estudiante`, `cn`.`valor_anterior` AS `valor_anterior`, `cn`.`valor_nuevo` AS `valor_nuevo`, `cn`.`fecha_correcion` AS `fecha_correcion`, coalesce(`cn`.`valor_nuevo`,`nd`.`valor_original`) AS `valor_final` FROM (`v_nota_parcial_detalle` `nd` left join (select `c1`.`id_Correcion_Nota` AS `id_Correcion_Nota`,`c1`.`valor_anterior` AS `valor_anterior`,`c1`.`valor_nuevo` AS `valor_nuevo`,`c1`.`fecha_correcion` AS `fecha_correcion`,`c1`.`motivo` AS `motivo`,`c1`.`id_Nota_Parcial` AS `id_Nota_Parcial` from (`correcion_nota` `c1` join (select `correcion_nota`.`id_Nota_Parcial` AS `id_Nota_Parcial`,max(`correcion_nota`.`fecha_correcion`) AS `max_fecha` from `correcion_nota` group by `correcion_nota`.`id_Nota_Parcial`) `ult` on(`ult`.`id_Nota_Parcial` = `c1`.`id_Nota_Parcial` and `ult`.`max_fecha` = `c1`.`fecha_correcion`))) `cn` on(`cn`.`id_Nota_Parcial` = `nd`.`id_Nota_Parcial`)) ;
-- Error reading data for table u605613151_sistema_academ.v_nota_parcial_con_ultima_correccion: #1064 - You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'FROM `u605613151_sistema_academ`.`v_nota_parcial_con_ultima_correccion`' at line 1

-- --------------------------------------------------------

--
-- Table structure for table `v_nota_parcial_detalle`
--

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_nota_parcial_detalle`  AS SELECT `np`.`id_Nota_Parcial` AS `id_Nota_Parcial`, `np`.`tipo` AS `tipo`, `np`.`valor` AS `valor_original`, `np`.`fecha` AS `fecha`, `np`.`observacion` AS `observacion`, `d`.`id_Docente` AS `id_Docente`, concat(`pd`.`nombre`,' ',`pd`.`apellido`) AS `docente`, `e`.`id_Estudiante` AS `id_Estudiante`, concat(`pe`.`nombre`,' ',`pe`.`apellido`) AS `estudiante` FROM ((((`nota_parcial` `np` join `docente` `d` on(`d`.`id_Docente` = `np`.`id_Docente`)) left join `persona` `pd` on(`pd`.`id_Persona` = `d`.`id_Docente`)) join `estudiante` `e` on(`e`.`id_Estudiante` = `np`.`id_Estudiante`)) left join `persona` `pe` on(`pe`.`id_Persona` = `e`.`id_Estudiante`)) ;
-- Error reading data for table u605613151_sistema_academ.v_nota_parcial_detalle: #1064 - You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'FROM `u605613151_sistema_academ`.`v_nota_parcial_detalle`' at line 1

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_pago_detalle`
-- (See below for the actual view)
--
CREATE TABLE `v_pago_detalle` (
`id_Pago` bigint(20) unsigned
,`fecha` timestamp
,`descripcion` varchar(200)
,`monto` decimal(12,2)
,`estado` enum('PENDIENTE','PAGADO','ANULADO')
,`metodo_pago` enum('EFECTIVO','TARJETA','TRANSFERENCIA','OTRO')
,`id_Estudiante` bigint(20) unsigned
,`estudiante` varchar(181)
,`tipo_pago` varchar(11)
,`id_Inscripcion_Estudiante` bigint(20) unsigned
,`numero_cuota` int(10) unsigned
,`fecha_vencimiento` date
,`validacion_estado` enum('VALIDO','INVALIDO')
,`validacion_fecha` timestamp
,`validacion_observacion` varchar(200)
,`id_Apertura_Caja` bigint(20) unsigned
,`id_Caja` bigint(20) unsigned
,`caja_nombre` varchar(80)
,`id_cajero` bigint(20) unsigned
,`cajero_email` varchar(120)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_persona_usuario`
-- (See below for the actual view)
--
CREATE TABLE `v_persona_usuario` (
`id` bigint(20) unsigned
,`ci` varchar(20)
,`nombre` varchar(80)
,`apellido` varchar(100)
,`fecha_nacimiento` date
,`sexo` enum('M','F','X')
,`email` varchar(120)
,`usuario_creado` timestamp
,`usuario_actualizado` timestamp
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_usuario_roles_permisos`
-- (See below for the actual view)
--
CREATE TABLE `v_usuario_roles_permisos` (
`id_Usuario` bigint(20) unsigned
,`email` varchar(120)
,`roles` longtext
,`permisos_codigos` longtext
,`permisos` longtext
);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `apertura_caja`
--
ALTER TABLE `apertura_caja`
  ADD PRIMARY KEY (`id_Apertura_Caja`),
  ADD KEY `idx_ac_caja` (`id_Caja`),
  ADD KEY `idx_ac_usuario` (`id_Usuario`);

--
-- Indexes for table `asistencia`
--
ALTER TABLE `asistencia`
  ADD PRIMARY KEY (`id_Estudiante`,`id_Oferta_Materia`),
  ADD KEY `idx_asistencia_oferta` (`id_Oferta_Materia`);

--
-- Indexes for table `aula`
--
ALTER TABLE `aula`
  ADD PRIMARY KEY (`id_Aula`),
  ADD UNIQUE KEY `uq_aula_codigo` (`codigo`),
  ADD KEY `idx_aula_tipo` (`id_Tipo_Aula`);

--
-- Indexes for table `caja`
--
ALTER TABLE `caja`
  ADD PRIMARY KEY (`id_Caja`),
  ADD UNIQUE KEY `uq_caja_nombre` (`nombre`);

--
-- Indexes for table `carrera`
--
ALTER TABLE `carrera`
  ADD PRIMARY KEY (`id_Carrera`),
  ADD UNIQUE KEY `uq_carrera_codigo` (`codigo`),
  ADD KEY `idx_carrera_facultad` (`id_Facultad`),
  ADD KEY `idx_carrera_usuario` (`id_usuario`);

--
-- Indexes for table `convalidacion_externa`
--
ALTER TABLE `convalidacion_externa`
  ADD PRIMARY KEY (`id_Convalidacion_Ext`),
  ADD KEY `idx_ce_est` (`id_Estudiante`),
  ADD KEY `idx_ce_usuario` (`id_Usuario`);

--
-- Indexes for table `convalidacion_externa_detalle`
--
ALTER TABLE `convalidacion_externa_detalle`
  ADD PRIMARY KEY (`id_Convalidacion_Ext`,`id_Materia`),
  ADD KEY `idx_ced_mat` (`id_Materia`);

--
-- Indexes for table `convalidacion_interna`
--
ALTER TABLE `convalidacion_interna`
  ADD PRIMARY KEY (`id_Convalidacion_Inte`),
  ADD KEY `fk_ci_plan_origen` (`id_Plan_Estudio_origen`),
  ADD KEY `fk_ci_plan_destino` (`id_Plan_Estudio_destino`),
  ADD KEY `idx_ci_est` (`id_Estudiante`),
  ADD KEY `idx_ci_usuario` (`id_Usuario`);

--
-- Indexes for table `convalidacion_interna_detalle`
--
ALTER TABLE `convalidacion_interna_detalle`
  ADD PRIMARY KEY (`id_Convalidacion_Inte`,`id_Materia`),
  ADD KEY `idx_cid_mat` (`id_Materia`);

--
-- Indexes for table `correcion_nota`
--
ALTER TABLE `correcion_nota`
  ADD PRIMARY KEY (`id_Correcion_Nota`),
  ADD KEY `idx_cn_np` (`id_Nota_Parcial`);

--
-- Indexes for table `docente`
--
ALTER TABLE `docente`
  ADD PRIMARY KEY (`id_Docente`);

--
-- Indexes for table `documento_estudiante`
--
ALTER TABLE `documento_estudiante`
  ADD PRIMARY KEY (`id_Documento_estudiante`),
  ADD UNIQUE KEY `uq_docest` (`id_Estudiante`,`id_Tipo_Documento`),
  ADD KEY `idx_docest_est` (`id_Estudiante`),
  ADD KEY `idx_docest_tipo` (`id_Tipo_Documento`);

--
-- Indexes for table `estudiante`
--
ALTER TABLE `estudiante`
  ADD PRIMARY KEY (`id_Estudiante`),
  ADD UNIQUE KEY `uq_estudiante_registro` (`nro_registro`);

--
-- Indexes for table `facultad`
--
ALTER TABLE `facultad`
  ADD PRIMARY KEY (`id_Facultad`),
  ADD UNIQUE KEY `uq_facultad_codigo` (`codigo`),
  ADD KEY `idx_facultad_univ` (`id_Universidad`);

--
-- Indexes for table `horario`
--
ALTER TABLE `horario`
  ADD PRIMARY KEY (`id_Horario`);

--
-- Indexes for table `inscripcion_estudiante`
--
ALTER TABLE `inscripcion_estudiante`
  ADD PRIMARY KEY (`id_Inscripcion_Estudiante`),
  ADD KEY `idx_insc_usuario` (`id_Usuario`),
  ADD KEY `fk_insc_estudiante` (`id_Estudiante`);

--
-- Indexes for table `materia`
--
ALTER TABLE `materia`
  ADD PRIMARY KEY (`id_Materia`),
  ADD UNIQUE KEY `uq_materia_codigo` (`codigo`),
  ADD UNIQUE KEY `uq_materia_sigla` (`sigla`);

--
-- Indexes for table `nota_parcial`
--
ALTER TABLE `nota_parcial`
  ADD PRIMARY KEY (`id_Nota_Parcial`),
  ADD KEY `idx_np_doc` (`id_Docente`),
  ADD KEY `idx_np_est` (`id_Estudiante`),
  ADD KEY `idx_np_fecha` (`fecha`),
  ADD KEY `idx_np_oferta` (`id_Oferta_Materia`);

--
-- Indexes for table `oferta_materia`
--
ALTER TABLE `oferta_materia`
  ADD PRIMARY KEY (`id_Oferta_Materia`),
  ADD KEY `fk_om_aula` (`id_Aula`),
  ADD KEY `fk_om_horario` (`id_Horario`),
  ADD KEY `idx_om_periodo` (`id_Periodo_Academico`),
  ADD KEY `idx_om_materia` (`id_Materia`),
  ADD KEY `idx_om_docente` (`id_Docente`),
  ADD KEY `idx_om_usuario` (`id_Usuario`);

--
-- Indexes for table `pago`
--
ALTER TABLE `pago`
  ADD PRIMARY KEY (`id_Pago`),
  ADD KEY `idx_pago_est` (`id_Estudiante`),
  ADD KEY `idx_pago_usuario` (`id_Usuario`),
  ADD KEY `idx_pago_apc` (`id_Apertura_Caja`),
  ADD KEY `idx_pago_estado` (`estado`);

--
-- Indexes for table `pago_inscripcion`
--
ALTER TABLE `pago_inscripcion`
  ADD PRIMARY KEY (`id_Pago`),
  ADD KEY `idx_pi_insc` (`id_Inscripcion_Estudiante`);

--
-- Indexes for table `pago_materia`
--
ALTER TABLE `pago_materia`
  ADD PRIMARY KEY (`id_Pago`);

--
-- Indexes for table `pensum`
--
ALTER TABLE `pensum`
  ADD PRIMARY KEY (`id_Plan_Estudio`,`id_Materia`),
  ADD KEY `idx_pensum_plan` (`id_Plan_Estudio`),
  ADD KEY `idx_pensum_materia` (`id_Materia`);

--
-- Indexes for table `periodo_academico`
--
ALTER TABLE `periodo_academico`
  ADD PRIMARY KEY (`id_Periodo_Academico`),
  ADD KEY `idx_periodo_unico` (`anio`,`semestre`,`modulo`);

--
-- Indexes for table `permiso`
--
ALTER TABLE `permiso`
  ADD PRIMARY KEY (`id_Permiso`),
  ADD UNIQUE KEY `uq_permiso_codigo` (`codigo`);

--
-- Indexes for table `persona`
--
ALTER TABLE `persona`
  ADD PRIMARY KEY (`id_Persona`),
  ADD UNIQUE KEY `uq_persona_ci` (`ci`);

--
-- Indexes for table `plan_estudio`
--
ALTER TABLE `plan_estudio`
  ADD PRIMARY KEY (`id_Plan_Estudio`),
  ADD UNIQUE KEY `uq_plan_numero` (`nro_Plan`),
  ADD KEY `idx_plan_estudiante` (`id_Estudiante`),
  ADD KEY `fk_plan_carrera` (`id_Carrera`);

--
-- Indexes for table `registro_materia`
--
ALTER TABLE `registro_materia`
  ADD PRIMARY KEY (`id_Registro_Materia`),
  ADD UNIQUE KEY `uq_rm` (`id_Estudiante`,`id_Oferta_Materia`),
  ADD KEY `idx_rm_est` (`id_Estudiante`),
  ADD KEY `idx_rm_oferta` (`id_Oferta_Materia`);

--
-- Indexes for table `retiro_materia`
--
ALTER TABLE `retiro_materia`
  ADD PRIMARY KEY (`id_Retiro_Materia`),
  ADD KEY `idx_retiro_rm` (`id_Registro_Materia`);

--
-- Indexes for table `rol`
--
ALTER TABLE `rol`
  ADD PRIMARY KEY (`id_Rol`),
  ADD UNIQUE KEY `uq_rol_nombre` (`nombre`);

--
-- Indexes for table `rol_permiso`
--
ALTER TABLE `rol_permiso`
  ADD PRIMARY KEY (`id_Rol`,`id_Permiso`),
  ADD KEY `idx_rp_rol` (`id_Rol`),
  ADD KEY `idx_rp_permiso` (`id_Permiso`);

--
-- Indexes for table `tipo_aula`
--
ALTER TABLE `tipo_aula`
  ADD PRIMARY KEY (`id_Tipo_Aula`),
  ADD UNIQUE KEY `uq_tipo_aula` (`nombre`);

--
-- Indexes for table `tipo_cuota`
--
ALTER TABLE `tipo_cuota`
  ADD PRIMARY KEY (`id_Tipo_Cuota`),
  ADD UNIQUE KEY `uq_tipo_cuota` (`nombre`);

--
-- Indexes for table `tipo_documento`
--
ALTER TABLE `tipo_documento`
  ADD PRIMARY KEY (`id_Tipo_Documento`),
  ADD UNIQUE KEY `uq_tipo_documento_nombre` (`nombre`);

--
-- Indexes for table `universidad`
--
ALTER TABLE `universidad`
  ADD PRIMARY KEY (`id_Universidad`),
  ADD UNIQUE KEY `uq_universidad_nombre` (`nombre`);

--
-- Indexes for table `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`id_Usuario`),
  ADD UNIQUE KEY `uq_usuario_email` (`email`);

--
-- Indexes for table `usuario_rol`
--
ALTER TABLE `usuario_rol`
  ADD PRIMARY KEY (`id_Usuario`,`id_Rol`),
  ADD KEY `idx_ur_usuario` (`id_Usuario`),
  ADD KEY `idx_ur_rol` (`id_Rol`);

--
-- Indexes for table `validacion_pago`
--
ALTER TABLE `validacion_pago`
  ADD PRIMARY KEY (`id_Validacion_Pago`),
  ADD KEY `idx_vp_pago` (`id_Pago`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `apertura_caja`
--
ALTER TABLE `apertura_caja`
  MODIFY `id_Apertura_Caja` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `aula`
--
ALTER TABLE `aula`
  MODIFY `id_Aula` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `caja`
--
ALTER TABLE `caja`
  MODIFY `id_Caja` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `carrera`
--
ALTER TABLE `carrera`
  MODIFY `id_Carrera` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `convalidacion_externa`
--
ALTER TABLE `convalidacion_externa`
  MODIFY `id_Convalidacion_Ext` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `convalidacion_interna`
--
ALTER TABLE `convalidacion_interna`
  MODIFY `id_Convalidacion_Inte` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `correcion_nota`
--
ALTER TABLE `correcion_nota`
  MODIFY `id_Correcion_Nota` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `documento_estudiante`
--
ALTER TABLE `documento_estudiante`
  MODIFY `id_Documento_estudiante` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `facultad`
--
ALTER TABLE `facultad`
  MODIFY `id_Facultad` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `horario`
--
ALTER TABLE `horario`
  MODIFY `id_Horario` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `inscripcion_estudiante`
--
ALTER TABLE `inscripcion_estudiante`
  MODIFY `id_Inscripcion_Estudiante` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `materia`
--
ALTER TABLE `materia`
  MODIFY `id_Materia` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `nota_parcial`
--
ALTER TABLE `nota_parcial`
  MODIFY `id_Nota_Parcial` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `oferta_materia`
--
ALTER TABLE `oferta_materia`
  MODIFY `id_Oferta_Materia` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pago`
--
ALTER TABLE `pago`
  MODIFY `id_Pago` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `periodo_academico`
--
ALTER TABLE `periodo_academico`
  MODIFY `id_Periodo_Academico` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `permiso`
--
ALTER TABLE `permiso`
  MODIFY `id_Permiso` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `persona`
--
ALTER TABLE `persona`
  MODIFY `id_Persona` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2011;

--
-- AUTO_INCREMENT for table `plan_estudio`
--
ALTER TABLE `plan_estudio`
  MODIFY `id_Plan_Estudio` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `registro_materia`
--
ALTER TABLE `registro_materia`
  MODIFY `id_Registro_Materia` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `retiro_materia`
--
ALTER TABLE `retiro_materia`
  MODIFY `id_Retiro_Materia` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `rol`
--
ALTER TABLE `rol`
  MODIFY `id_Rol` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `tipo_aula`
--
ALTER TABLE `tipo_aula`
  MODIFY `id_Tipo_Aula` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `tipo_cuota`
--
ALTER TABLE `tipo_cuota`
  MODIFY `id_Tipo_Cuota` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `tipo_documento`
--
ALTER TABLE `tipo_documento`
  MODIFY `id_Tipo_Documento` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `universidad`
--
ALTER TABLE `universidad`
  MODIFY `id_Universidad` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `validacion_pago`
--
ALTER TABLE `validacion_pago`
  MODIFY `id_Validacion_Pago` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

-- --------------------------------------------------------

--
-- Structure for view `v_docente_perfil`
--
DROP TABLE IF EXISTS `v_docente_perfil`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_docente_perfil`  AS SELECT `d`.`id_Docente` AS `id`, `pu`.`ci` AS `ci`, `pu`.`nombre` AS `nombre`, `pu`.`apellido` AS `apellido`, `d`.`fecha_contratacion` AS `fecha_contratacion`, `d`.`estado` AS `estado`, `d`.`certificacion` AS `certificacion`, `pu`.`email` AS `email` FROM (`docente` `d` left join `v_persona_usuario` `pu` on(`pu`.`id` = `d`.`id_Docente`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_estado_caja`
--
DROP TABLE IF EXISTS `v_estado_caja`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_estado_caja`  AS SELECT `c`.`id_Caja` AS `id_Caja`, `c`.`nombre` AS `caja`, `ac`.`id_Apertura_Caja` AS `id_Apertura_Caja`, `ac`.`fecha_apertura` AS `fecha_apertura`, `ac`.`fecha_cierre` AS `fecha_cierre`, `ac`.`estado` AS `estado`, `ac`.`id_Usuario` AS `id_usuario_apertura`, `pu`.`email` AS `usuario_apertura` FROM (((`caja` `c` left join (select `a1`.`id_Apertura_Caja` AS `id_Apertura_Caja`,`a1`.`fecha_apertura` AS `fecha_apertura`,`a1`.`fecha_cierre` AS `fecha_cierre`,`a1`.`estado` AS `estado`,`a1`.`id_Caja` AS `id_Caja`,`a1`.`id_Usuario` AS `id_Usuario` from (`apertura_caja` `a1` join (select `apertura_caja`.`id_Caja` AS `id_Caja`,max(`apertura_caja`.`fecha_apertura`) AS `max_apertura` from `apertura_caja` group by `apertura_caja`.`id_Caja`) `ult` on(`ult`.`id_Caja` = `a1`.`id_Caja` and `ult`.`max_apertura` = `a1`.`fecha_apertura`))) `ac` on(`ac`.`id_Caja` = `c`.`id_Caja`)) left join `usuario` `u` on(`u`.`id_Usuario` = `ac`.`id_Usuario`)) left join `v_persona_usuario` `pu` on(`pu`.`id` = `u`.`id_Usuario`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_estudiante_perfil`
--
DROP TABLE IF EXISTS `v_estudiante_perfil`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_estudiante_perfil`  AS SELECT `e`.`id_Estudiante` AS `id`, `pu`.`ci` AS `ci`, `pu`.`nombre` AS `nombre`, `pu`.`apellido` AS `apellido`, `e`.`nro_registro` AS `nro_registro`, `e`.`estado` AS `estado_estudiante`, `pu`.`email` AS `email`, `pe`.`id_Plan_Estudio` AS `id_Plan_Estudio`, `pe`.`nro_Plan` AS `nro_Plan`, `pe`.`estado` AS `estado_plan`, `c`.`id_Carrera` AS `id_Carrera`, `c`.`codigo` AS `codigo_carrera`, `c`.`nombre` AS `nombre_carrera` FROM (((`estudiante` `e` left join `v_persona_usuario` `pu` on(`pu`.`id` = `e`.`id_Estudiante`)) left join `plan_estudio` `pe` on(`pe`.`id_Estudiante` = `e`.`id_Estudiante` and `pe`.`estado` = 'ACTIVO')) left join `carrera` `c` on(`c`.`id_Carrera` = `pe`.`id_Carrera`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_inscripcion_estudiante_detalle`
--
DROP TABLE IF EXISTS `v_inscripcion_estudiante_detalle`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_inscripcion_estudiante_detalle`  AS SELECT `ie`.`id_Inscripcion_Estudiante` AS `id_Inscripcion_Estudiante`, `ie`.`fecha_inscripcion` AS `fecha_inscripcion`, `ie`.`estado` AS `estado`, `ie`.`observaciones` AS `observaciones`, `ie`.`id_Usuario` AS `id_operador`, `pu`.`email` AS `operador_email` FROM (`inscripcion_estudiante` `ie` left join `v_persona_usuario` `pu` on(`pu`.`id` = `ie`.`id_Usuario`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_pago_detalle`
--
DROP TABLE IF EXISTS `v_pago_detalle`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_pago_detalle`  AS SELECT `p`.`id_Pago` AS `id_Pago`, `p`.`fecha` AS `fecha`, `p`.`descripcion` AS `descripcion`, `p`.`monto` AS `monto`, `p`.`estado` AS `estado`, `p`.`metodo_pago` AS `metodo_pago`, `e`.`id_Estudiante` AS `id_Estudiante`, concat(`pe`.`nombre`,' ',`pe`.`apellido`) AS `estudiante`, CASE WHEN `pi`.`id_Pago` is not null THEN 'INSCRIPCION' WHEN `pm`.`id_Pago` is not null THEN 'MATERIA' ELSE 'OTRO' END AS `tipo_pago`, `pi`.`id_Inscripcion_Estudiante` AS `id_Inscripcion_Estudiante`, `pm`.`numero_cuota` AS `numero_cuota`, `pm`.`fecha_vencimiento` AS `fecha_vencimiento`, `vp`.`estado` AS `validacion_estado`, `vp`.`fecha` AS `validacion_fecha`, `vp`.`observacion` AS `validacion_observacion`, `ac`.`id_Apertura_Caja` AS `id_Apertura_Caja`, `ac`.`id_Caja` AS `id_Caja`, `c`.`nombre` AS `caja_nombre`, `u`.`id_Usuario` AS `id_cajero`, `pu`.`email` AS `cajero_email` FROM (((((((((`pago` `p` join `estudiante` `e` on(`e`.`id_Estudiante` = `p`.`id_Estudiante`)) left join `persona` `pe` on(`pe`.`id_Persona` = `e`.`id_Estudiante`)) left join `pago_inscripcion` `pi` on(`pi`.`id_Pago` = `p`.`id_Pago`)) left join `pago_materia` `pm` on(`pm`.`id_Pago` = `p`.`id_Pago`)) left join (select `v1`.`id_Validacion_Pago` AS `id_Validacion_Pago`,`v1`.`estado` AS `estado`,`v1`.`fecha` AS `fecha`,`v1`.`observacion` AS `observacion`,`v1`.`id_Pago` AS `id_Pago` from (`validacion_pago` `v1` join (select `validacion_pago`.`id_Pago` AS `id_Pago`,max(`validacion_pago`.`fecha`) AS `max_fecha` from `validacion_pago` group by `validacion_pago`.`id_Pago`) `ult` on(`ult`.`id_Pago` = `v1`.`id_Pago` and `ult`.`max_fecha` = `v1`.`fecha`))) `vp` on(`vp`.`id_Pago` = `p`.`id_Pago`)) left join `apertura_caja` `ac` on(`ac`.`id_Apertura_Caja` = `p`.`id_Apertura_Caja`)) left join `caja` `c` on(`c`.`id_Caja` = `ac`.`id_Caja`)) left join `usuario` `u` on(`u`.`id_Usuario` = `p`.`id_Usuario`)) left join `v_persona_usuario` `pu` on(`pu`.`id` = `u`.`id_Usuario`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_persona_usuario`
--
DROP TABLE IF EXISTS `v_persona_usuario`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_persona_usuario`  AS SELECT `p`.`id_Persona` AS `id`, `p`.`ci` AS `ci`, `p`.`nombre` AS `nombre`, `p`.`apellido` AS `apellido`, `p`.`fecha_nacimiento` AS `fecha_nacimiento`, `p`.`sexo` AS `sexo`, `u`.`email` AS `email`, `u`.`created_at` AS `usuario_creado`, `u`.`updated_at` AS `usuario_actualizado` FROM (`persona` `p` left join `usuario` `u` on(`u`.`id_Usuario` = `p`.`id_Persona`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_usuario_roles_permisos`
--
DROP TABLE IF EXISTS `v_usuario_roles_permisos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`u605613151_admin`@`127.0.0.1` SQL SECURITY DEFINER VIEW `v_usuario_roles_permisos`  AS SELECT `u`.`id_Usuario` AS `id_Usuario`, `u`.`email` AS `email`, group_concat(distinct `r`.`nombre` order by `r`.`nombre` ASC separator ', ') AS `roles`, group_concat(distinct `pe`.`codigo` order by `pe`.`codigo` ASC separator ', ') AS `permisos_codigos`, group_concat(distinct `pe`.`descripcion` order by `pe`.`descripcion` ASC separator '; ') AS `permisos` FROM ((((`usuario` `u` left join `usuario_rol` `ur` on(`ur`.`id_Usuario` = `u`.`id_Usuario`)) left join `rol` `r` on(`r`.`id_Rol` = `ur`.`id_Rol`)) left join `rol_permiso` `rp` on(`rp`.`id_Rol` = `r`.`id_Rol`)) left join `permiso` `pe` on(`pe`.`id_Permiso` = `rp`.`id_Permiso`)) GROUP BY `u`.`id_Usuario`, `u`.`email` ;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `apertura_caja`
--
ALTER TABLE `apertura_caja`
  ADD CONSTRAINT `fk_ac_caja` FOREIGN KEY (`id_Caja`) REFERENCES `caja` (`id_Caja`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ac_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `asistencia`
--
ALTER TABLE `asistencia`
  ADD CONSTRAINT `fk_asistencia_estudiante` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_asistencia_oferta` FOREIGN KEY (`id_Oferta_Materia`) REFERENCES `oferta_materia` (`id_Oferta_Materia`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `aula`
--
ALTER TABLE `aula`
  ADD CONSTRAINT `fk_aula_tipo` FOREIGN KEY (`id_Tipo_Aula`) REFERENCES `tipo_aula` (`id_Tipo_Aula`) ON UPDATE CASCADE;

--
-- Constraints for table `carrera`
--
ALTER TABLE `carrera`
  ADD CONSTRAINT `fk_carrera_facultad` FOREIGN KEY (`id_Facultad`) REFERENCES `facultad` (`id_Facultad`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_carrera_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario` (`id_Usuario`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `convalidacion_externa`
--
ALTER TABLE `convalidacion_externa`
  ADD CONSTRAINT `fk_ce_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ce_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `convalidacion_externa_detalle`
--
ALTER TABLE `convalidacion_externa_detalle`
  ADD CONSTRAINT `fk_ced_ce` FOREIGN KEY (`id_Convalidacion_Ext`) REFERENCES `convalidacion_externa` (`id_Convalidacion_Ext`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ced_mat` FOREIGN KEY (`id_Materia`) REFERENCES `materia` (`id_Materia`) ON UPDATE CASCADE;

--
-- Constraints for table `convalidacion_interna`
--
ALTER TABLE `convalidacion_interna`
  ADD CONSTRAINT `fk_ci_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ci_plan_destino` FOREIGN KEY (`id_Plan_Estudio_destino`) REFERENCES `plan_estudio` (`id_Plan_Estudio`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ci_plan_origen` FOREIGN KEY (`id_Plan_Estudio_origen`) REFERENCES `plan_estudio` (`id_Plan_Estudio`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ci_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `convalidacion_interna_detalle`
--
ALTER TABLE `convalidacion_interna_detalle`
  ADD CONSTRAINT `fk_cid_ci` FOREIGN KEY (`id_Convalidacion_Inte`) REFERENCES `convalidacion_interna` (`id_Convalidacion_Inte`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_cid_mat` FOREIGN KEY (`id_Materia`) REFERENCES `materia` (`id_Materia`) ON UPDATE CASCADE;

--
-- Constraints for table `correcion_nota`
--
ALTER TABLE `correcion_nota`
  ADD CONSTRAINT `fk_cn_np` FOREIGN KEY (`id_Nota_Parcial`) REFERENCES `nota_parcial` (`id_Nota_Parcial`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `docente`
--
ALTER TABLE `docente`
  ADD CONSTRAINT `fk_docente_usuario` FOREIGN KEY (`id_Docente`) REFERENCES `usuario` (`id_Usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `documento_estudiante`
--
ALTER TABLE `documento_estudiante`
  ADD CONSTRAINT `fk_docest_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_docest_tip` FOREIGN KEY (`id_Tipo_Documento`) REFERENCES `tipo_documento` (`id_Tipo_Documento`) ON UPDATE CASCADE;

--
-- Constraints for table `estudiante`
--
ALTER TABLE `estudiante`
  ADD CONSTRAINT `fk_estudiante_usuario` FOREIGN KEY (`id_Estudiante`) REFERENCES `usuario` (`id_Usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `facultad`
--
ALTER TABLE `facultad`
  ADD CONSTRAINT `fk_facultad_univ` FOREIGN KEY (`id_Universidad`) REFERENCES `universidad` (`id_Universidad`) ON UPDATE CASCADE;

--
-- Constraints for table `inscripcion_estudiante`
--
ALTER TABLE `inscripcion_estudiante`
  ADD CONSTRAINT `fk_insc_estudiante` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_insc_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `nota_parcial`
--
ALTER TABLE `nota_parcial`
  ADD CONSTRAINT `fk_np_doc` FOREIGN KEY (`id_Docente`) REFERENCES `docente` (`id_Docente`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_np_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_np_oferta` FOREIGN KEY (`id_Oferta_Materia`) REFERENCES `oferta_materia` (`id_Oferta_Materia`) ON UPDATE CASCADE;

--
-- Constraints for table `oferta_materia`
--
ALTER TABLE `oferta_materia`
  ADD CONSTRAINT `fk_om_aula` FOREIGN KEY (`id_Aula`) REFERENCES `aula` (`id_Aula`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_om_docente` FOREIGN KEY (`id_Docente`) REFERENCES `docente` (`id_Docente`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_om_horario` FOREIGN KEY (`id_Horario`) REFERENCES `horario` (`id_Horario`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_om_materia` FOREIGN KEY (`id_Materia`) REFERENCES `materia` (`id_Materia`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_om_periodo` FOREIGN KEY (`id_Periodo_Academico`) REFERENCES `periodo_academico` (`id_Periodo_Academico`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_om_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `pago`
--
ALTER TABLE `pago`
  ADD CONSTRAINT `fk_pago_apc` FOREIGN KEY (`id_Apertura_Caja`) REFERENCES `apertura_caja` (`id_Apertura_Caja`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pago_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pago_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON UPDATE CASCADE;

--
-- Constraints for table `pago_inscripcion`
--
ALTER TABLE `pago_inscripcion`
  ADD CONSTRAINT `fk_pi_insc` FOREIGN KEY (`id_Inscripcion_Estudiante`) REFERENCES `inscripcion_estudiante` (`id_Inscripcion_Estudiante`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pi_pago` FOREIGN KEY (`id_Pago`) REFERENCES `pago` (`id_Pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `pago_materia`
--
ALTER TABLE `pago_materia`
  ADD CONSTRAINT `fk_pm_pago` FOREIGN KEY (`id_Pago`) REFERENCES `pago` (`id_Pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `pensum`
--
ALTER TABLE `pensum`
  ADD CONSTRAINT `fk_pensum_materia` FOREIGN KEY (`id_Materia`) REFERENCES `materia` (`id_Materia`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pensum_plan` FOREIGN KEY (`id_Plan_Estudio`) REFERENCES `plan_estudio` (`id_Plan_Estudio`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `plan_estudio`
--
ALTER TABLE `plan_estudio`
  ADD CONSTRAINT `fk_plan_carrera` FOREIGN KEY (`id_Carrera`) REFERENCES `carrera` (`id_Carrera`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_plan_estudiante` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `registro_materia`
--
ALTER TABLE `registro_materia`
  ADD CONSTRAINT `fk_rm_est` FOREIGN KEY (`id_Estudiante`) REFERENCES `estudiante` (`id_Estudiante`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_rm_oferta` FOREIGN KEY (`id_Oferta_Materia`) REFERENCES `oferta_materia` (`id_Oferta_Materia`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `retiro_materia`
--
ALTER TABLE `retiro_materia`
  ADD CONSTRAINT `fk_retiro_rm` FOREIGN KEY (`id_Registro_Materia`) REFERENCES `registro_materia` (`id_Registro_Materia`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `rol_permiso`
--
ALTER TABLE `rol_permiso`
  ADD CONSTRAINT `fk_rp_permiso` FOREIGN KEY (`id_Permiso`) REFERENCES `permiso` (`id_Permiso`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_rp_rol` FOREIGN KEY (`id_Rol`) REFERENCES `rol` (`id_Rol`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `usuario`
--
ALTER TABLE `usuario`
  ADD CONSTRAINT `fk_usuario_persona` FOREIGN KEY (`id_Usuario`) REFERENCES `persona` (`id_Persona`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `usuario_rol`
--
ALTER TABLE `usuario_rol`
  ADD CONSTRAINT `fk_ur_rol` FOREIGN KEY (`id_Rol`) REFERENCES `rol` (`id_Rol`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ur_usuario` FOREIGN KEY (`id_Usuario`) REFERENCES `usuario` (`id_Usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `validacion_pago`
--
ALTER TABLE `validacion_pago`
  ADD CONSTRAINT `fk_vp_pago` FOREIGN KEY (`id_Pago`) REFERENCES `pago` (`id_Pago`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
