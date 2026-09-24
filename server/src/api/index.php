<?php
/**
 * 接口前端控制器。
 *
 * nginx 侧把 /api/ 下所有不存在实体的路径 try_files 到本文件（见宝塔
 * extension 目录里的 deny_internal.conf），本文件只做一件事：交给路由。
 * REQUEST_URI 保持不变，因此路由能还原出原始请求路径。
 */
require_once dirname(__DIR__) . '/app/bootstrap.php';

\Wid\Api\Router::dispatch();
